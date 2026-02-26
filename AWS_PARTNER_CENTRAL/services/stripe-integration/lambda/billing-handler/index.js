const AWS = require('aws-sdk');

const dynamodb = new AWS.DynamoDB.DocumentClient();
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
 * Billing Handler Lambda - Processes Stripe events from EventBridge
 *
 * EventBridge event structure:
 * {
 *   "version": "0",
 *   "id": "abc123",
 *   "detail-type": "invoice.payment_succeeded",
 *   "source": "aws.partner/stripe.com/acct_xxx/...",
 *   "account": "123456789012",
 *   "time": "2024-01-01T00:00:00Z",
 *   "region": "us-east-2",
 *   "detail": {
 *     "id": "evt_xxx",
 *     "object": "event",
 *     "type": "invoice.payment_succeeded",
 *     "data": { "object": { ... invoice data ... } }
 *   }
 * }
 */
exports.handler = async (event) => {
    console.log('Processing Stripe event from EventBridge:', JSON.stringify(event, null, 2));

    // EventBridge delivers Stripe events in the 'detail' field
    // The detail-type contains the event type (e.g., 'invoice.payment_succeeded')
    const eventType = event['detail-type'];
    const stripeEvent = event.detail;

    if (!stripeEvent || !eventType) {
        console.error('Invalid event structure - missing detail or detail-type');
        return { statusCode: 400, body: 'Invalid event structure' };
    }

    // For thin payloads, we may need to fetch the full object from Stripe
    const eventData = stripeEvent.data?.object || await fetchStripeObject(stripeEvent);

    try {
        switch (eventType) {
            case 'invoice.payment_succeeded':
                await handlePaymentSucceeded(eventData);
                break;
            case 'invoice.payment_failed':
                await handlePaymentFailed(eventData);
                break;
            case 'customer.subscription.created':
                await handleSubscriptionCreated(eventData);
                break;
            case 'customer.subscription.updated':
                await handleSubscriptionUpdated(eventData);
                break;
            case 'customer.subscription.deleted':
                await handleSubscriptionDeleted(eventData);
                break;
            default:
                console.log(`Unhandled event type: ${eventType}`);
        }

        return { statusCode: 200, body: JSON.stringify({ received: true, type: eventType }) };
    } catch (error) {
        console.error('Error processing event:', error);
        // Don't throw - let EventBridge handle retries via DLQ if configured
        return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
    }
};

/**
 * For thin payloads, fetch the full object from Stripe API
 * Thin payloads only contain object ID and type, not the full data
 */
async function fetchStripeObject(stripeEvent) {
    const relatedObject = stripeEvent.related_object;
    if (!relatedObject) {
        console.log('No related_object in thin payload, returning event as-is');
        return stripeEvent;
    }

    console.log(`Fetching full object: ${relatedObject.type}/${relatedObject.id}`);
    const stripe = await getStripeClient();

    try {
        switch (relatedObject.type) {
            case 'invoice':
                return await stripe.invoices.retrieve(relatedObject.id);
            case 'subscription':
                return await stripe.subscriptions.retrieve(relatedObject.id);
            case 'customer':
                return await stripe.customers.retrieve(relatedObject.id);
            default:
                console.log(`Unknown object type: ${relatedObject.type}`);
                return stripeEvent;
        }
    } catch (error) {
        console.error(`Failed to fetch ${relatedObject.type}/${relatedObject.id}:`, error);
        throw error;
    }
}

async function handlePaymentSucceeded(invoice) {
    console.log('Payment succeeded for invoice:', invoice.id);

    const params = {
        TableName: process.env.BILLING_TABLE_NAME,
        Item: {
            id: invoice.id,
            customerId: invoice.customer,
            amount: invoice.amount_due || invoice.amount_paid,
            currency: invoice.currency,
            status: 'paid',
            paidAt: new Date().toISOString(),
            description: invoice.description || 'AWS Usage Payment',
            metadata: invoice.metadata || {}
        }
    };

    await dynamodb.put(params).promise();
    await sendNotification(`Payment successful: $${(invoice.amount_due || invoice.amount_paid) / 100} for invoice ${invoice.id}`);
}

async function handlePaymentFailed(invoice) {
    console.log('Payment failed for invoice:', invoice.id);

    const params = {
        TableName: process.env.BILLING_TABLE_NAME,
        Item: {
            id: invoice.id,
            customerId: invoice.customer,
            amount: invoice.amount_due,
            currency: invoice.currency,
            status: 'failed',
            failedAt: new Date().toISOString(),
            description: 'AWS Usage Payment Failed',
            attemptCount: invoice.attempt_count || 1
        }
    };

    await dynamodb.put(params).promise();
    await sendNotification(`Payment FAILED: $${invoice.amount_due / 100} for invoice ${invoice.id} - Attempt ${invoice.attempt_count || 1}`);
}

async function handleSubscriptionCreated(subscription) {
    console.log('Subscription created:', subscription.id);

    const params = {
        TableName: process.env.SUBSCRIPTIONS_TABLE_NAME,
        Item: {
            id: subscription.id,
            customerId: subscription.customer,
            status: subscription.status,
            currentPeriodStart: new Date(subscription.current_period_start * 1000).toISOString(),
            currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
            createdAt: new Date().toISOString(),
            priceId: subscription.items?.data?.[0]?.price?.id,
            quantity: subscription.items?.data?.[0]?.quantity
        }
    };

    await dynamodb.put(params).promise();
    await sendNotification(`New subscription created: ${subscription.id} for customer ${subscription.customer}`);
}

async function handleSubscriptionUpdated(subscription) {
    console.log('Subscription updated:', subscription.id);

    const params = {
        TableName: process.env.SUBSCRIPTIONS_TABLE_NAME,
        Key: { id: subscription.id },
        UpdateExpression: 'SET #status = :status, currentPeriodStart = :start, currentPeriodEnd = :end, updatedAt = :updated',
        ExpressionAttributeNames: {
            '#status': 'status'
        },
        ExpressionAttributeValues: {
            ':status': subscription.status,
            ':start': new Date(subscription.current_period_start * 1000).toISOString(),
            ':end': new Date(subscription.current_period_end * 1000).toISOString(),
            ':updated': new Date().toISOString()
        }
    };

    await dynamodb.update(params).promise();
}

async function handleSubscriptionDeleted(subscription) {
    console.log('Subscription deleted:', subscription.id);

    const params = {
        TableName: process.env.SUBSCRIPTIONS_TABLE_NAME,
        Key: { id: subscription.id },
        UpdateExpression: 'SET #status = :status, cancelledAt = :cancelled',
        ExpressionAttributeNames: {
            '#status': 'status'
        },
        ExpressionAttributeValues: {
            ':status': 'cancelled',
            ':cancelled': new Date().toISOString()
        }
    };

    await dynamodb.update(params).promise();
    await sendNotification(`Subscription cancelled: ${subscription.id}`);
}

async function sendNotification(message) {
    const sns = new AWS.SNS();
    const params = {
        TopicArn: process.env.SNS_TOPIC_ARN,
        Message: message,
        Subject: 'Stripe Billing Event'
    };

    try {
        await sns.publish(params).promise();
        console.log('Notification sent:', message);
    } catch (error) {
        console.error('Failed to send notification:', error);
        // Don't throw - notification failure shouldn't fail the event processing
    }
}
