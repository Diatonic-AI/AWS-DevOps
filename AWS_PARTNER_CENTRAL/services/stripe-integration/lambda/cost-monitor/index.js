const AWS = require('aws-sdk');

const costexplorer = new AWS.CostExplorer({ region: process.env.AWS_REGION || 'us-east-1' });
const ssm = new AWS.SSM();

// Cache for Stripe client (reused across invocations)
let stripeClient = null;

/**
 * Get Stripe secret key from SSM Parameter Store (cached)
 */
async function getStripeClient() {
    if (stripeClient) {
        return stripeClient;
    }

    const paramPath = process.env.STRIPE_SECRET_KEY_PATH || '/stripe/secret-key';
    console.log(`Fetching Stripe secret from SSM: ${paramPath}`);

    const result = await ssm.getParameter({
        Name: paramPath,
        WithDecryption: true
    }).promise();

    const Stripe = require('stripe');
    stripeClient = Stripe(result.Parameter.Value);
    return stripeClient;
}

/**
 * Cost Monitor Lambda - Checks AWS costs and creates Stripe invoices when needed
 * Triggered daily by EventBridge scheduled rule
 */
exports.handler = async (event) => {
    console.log('Starting cost monitoring...');

    try {
        // Get current month's costs
        const endDate = new Date();
        const startDate = new Date(endDate.getFullYear(), endDate.getMonth(), 1);

        const costParams = {
            TimePeriod: {
                Start: startDate.toISOString().split('T')[0],
                End: endDate.toISOString().split('T')[0]
            },
            Granularity: 'MONTHLY',
            Metrics: ['BlendedCost']
        };

        const costData = await costexplorer.getCostAndUsage(costParams).promise();

        // Handle case where no data is returned
        let currentCost = 0;
        if (costData.ResultsByTime && costData.ResultsByTime.length > 0) {
            const result = costData.ResultsByTime[0];
            if (result.Total && result.Total.BlendedCost) {
                currentCost = parseFloat(result.Total.BlendedCost.Amount);
            } else if (result.Groups && result.Groups.length > 0) {
                currentCost = parseFloat(result.Groups[0].Metrics.BlendedCost.Amount);
            }
        }

        console.log(`Current month cost: $${currentCost.toFixed(2)}`);

        // Check against budget threshold
        const budgetThreshold = parseFloat(process.env.BUDGET_THRESHOLD) || 800;
        if (currentCost > budgetThreshold) {
            console.log(`Budget threshold exceeded! Cost: $${currentCost.toFixed(2)} > Threshold: $${budgetThreshold}`);

            // Create Stripe invoice
            await createStripeInvoice(currentCost);

            // Send notification
            await sendNotification(`Budget alert: Current cost $${currentCost.toFixed(2)} exceeds threshold $${budgetThreshold}`);
        } else {
            console.log(`Cost within budget: $${currentCost.toFixed(2)} / $${budgetThreshold}`);
        }

        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Cost monitoring completed',
                currentCost: currentCost.toFixed(2),
                budgetThreshold,
                exceededBudget: currentCost > budgetThreshold
            })
        };
    } catch (error) {
        console.error('Error in cost monitoring:', error);
        await sendNotification(`Cost monitoring error: ${error.message}`);
        throw error;
    }
};

async function createStripeInvoice(amount) {
    try {
        const stripe = await getStripeClient();
        const customerId = process.env.STRIPE_CUSTOMER_ID;

        if (!customerId) {
            console.log('No STRIPE_CUSTOMER_ID configured, skipping invoice creation');
            return;
        }

        const invoice = await stripe.invoices.create({
            customer: customerId,
            auto_advance: true,
            collection_method: 'charge_automatically'
        });

        // Add line item for AWS costs
        await stripe.invoiceItems.create({
            customer: customerId,
            invoice: invoice.id,
            amount: Math.round(amount * 100), // Convert to cents
            currency: 'usd',
            description: `AWS Usage Costs - ${new Date().toISOString().slice(0, 7)}`
        });

        // Finalize invoice
        await stripe.invoices.finalizeInvoice(invoice.id);

        console.log('Stripe invoice created:', invoice.id);
        return invoice;
    } catch (error) {
        console.error('Error creating Stripe invoice:', error);
        // Don't throw - we still want to report the cost monitoring results
    }
}

async function sendNotification(message) {
    const sns = new AWS.SNS();
    const params = {
        TopicArn: process.env.SNS_TOPIC_ARN,
        Message: message,
        Subject: 'AWS Billing Alert'
    };

    try {
        await sns.publish(params).promise();
        console.log('Notification sent:', message);
    } catch (error) {
        console.error('Failed to send notification:', error);
    }
}
