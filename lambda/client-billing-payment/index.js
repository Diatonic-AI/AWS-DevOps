/**
 * Client Billing Portal - Stripe Payment Processing Lambda
 * Handles payment method setup and invoice payments via Stripe
 */

const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");
const { DynamoDBDocumentClient, PutCommand, GetCommand, UpdateCommand } = require("@aws-sdk/lib-dynamodb");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { SESClient, SendEmailCommand } = require("@aws-sdk/client-ses");

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION || "us-east-1" });
const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" }));
const sesClient = new SESClient({ region: process.env.AWS_REGION || "us-east-1" });

const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE || "client-billing-data";
const STRIPE_SECRET_NAME = process.env.STRIPE_SECRET_NAME || "client-billing/stripe-api-key";

let stripeInstance = null;

/**
 * Get Stripe API key from Secrets Manager and initialize Stripe
 */
async function getStripe() {
    if (stripeInstance) return stripeInstance;

    try {
        const command = new GetSecretValueCommand({ SecretId: STRIPE_SECRET_NAME });
        const secret = await secretsClient.send(command);
        const apiKey = JSON.parse(secret.SecretString).apiKey;

        const stripe = require('stripe')(apiKey);
        stripeInstance = stripe;
        return stripe;
    } catch (error) {
        console.error("Error getting Stripe API key:", error);
        throw new Error("Failed to initialize Stripe");
    }
}

/**
 * Create or retrieve Stripe customer
 */
async function getOrCreateStripeCustomer(stripe, clientData) {
    const { clientId, clientName, email } = clientData;

    // Check if customer exists in DynamoDB
    const getParams = {
        TableName: DYNAMODB_TABLE,
        Key: {
            clientId: clientId,
            billingPeriod: "stripe-customer"
        }
    };

    try {
        const result = await ddbClient.send(new GetCommand(getParams));
        if (result.Item && result.Item.stripeCustomerId) {
            return result.Item.stripeCustomerId;
        }
    } catch (error) {
        console.log("No existing Stripe customer found, creating new one");
    }

    // Create new Stripe customer
    const customer = await stripe.customers.create({
        name: clientName,
        email: email,
        metadata: {
            clientId: clientId,
            awsAccountId: clientData.accountId || ""
        }
    });

    // Save to DynamoDB
    await ddbClient.send(new PutCommand({
        TableName: DYNAMODB_TABLE,
        Item: {
            clientId: clientId,
            billingPeriod: "stripe-customer",
            stripeCustomerId: customer.id,
            createdAt: new Date().toISOString()
        }
    }));

    return customer.id;
}

/**
 * Create Stripe Checkout Session for payment method setup
 */
async function createPaymentMethodSetup(stripe, customerId, clientData) {
    const session = await stripe.checkout.sessions.create({
        customer: customerId,
        mode: 'setup',
        payment_method_types: ['card'],
        success_url: `${clientData.portalUrl}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${clientData.portalUrl}/payment-cancel`,
        metadata: {
            clientId: clientData.clientId,
            type: 'payment_method_setup'
        }
    });

    return session;
}

/**
 * Create invoice and payment intent
 */
async function createInvoice(stripe, customerId, clientData, amount) {
    // Create invoice item
    const invoiceItem = await stripe.invoiceItems.create({
        customer: customerId,
        amount: Math.round(amount * 100), // Convert to cents
        currency: 'usd',
        description: `AWS Services - ${clientData.billingPeriod}`,
        metadata: {
            clientId: clientData.clientId,
            billingPeriod: clientData.billingPeriod
        }
    });

    // Create invoice
    const invoice = await stripe.invoices.create({
        customer: customerId,
        auto_advance: false, // Don't auto-finalize
        collection_method: 'charge_automatically',
        metadata: {
            clientId: clientData.clientId,
            billingPeriod: clientData.billingPeriod
        }
    });

    // Finalize invoice
    await stripe.invoices.finalizeInvoice(invoice.id);

    // Save invoice to DynamoDB
    await ddbClient.send(new PutCommand({
        TableName: DYNAMODB_TABLE,
        Item: {
            clientId: clientData.clientId,
            billingPeriod: `invoice-${clientData.billingPeriod}`,
            stripeInvoiceId: invoice.id,
            amount: amount,
            status: 'created',
            createdAt: new Date().toISOString()
        }
    }));

    return invoice;
}

/**
 * Send email notification
 */
async function sendEmailNotification(to, subject, body) {
    const params = {
        Source: process.env.SES_SENDER_EMAIL || "noreply@mmptoledo.com",
        Destination: {
            ToAddresses: [to]
        },
        Message: {
            Subject: { Data: subject },
            Body: {
                Html: { Data: body }
            }
        }
    };

    try {
        await sesClient.send(new SendEmailCommand(params));
        console.log(`Email sent to ${to}`);
    } catch (error) {
        console.error("Error sending email:", error);
    }
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
    console.log("Event:", JSON.stringify(event, null, 2));

    try {
        const body = event.body ? JSON.parse(event.body) : event;
        const action = body.action || event.queryStringParameters?.action;

        const stripe = await getStripe();

        switch (action) {
            case 'setup-payment-method': {
                // Client wants to add payment method
                const customerId = await getOrCreateStripeCustomer(stripe, {
                    clientId: body.clientId,
                    clientName: body.clientName,
                    email: body.email,
                    accountId: body.accountId
                });

                const session = await createPaymentMethodSetup(stripe, customerId, {
                    clientId: body.clientId,
                    portalUrl: body.portalUrl || process.env.PORTAL_URL
                });

                return {
                    statusCode: 200,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    },
                    body: JSON.stringify({
                        sessionId: session.id,
                        url: session.url
                    })
                };
            }

            case 'create-invoice': {
                // Create invoice for billing period
                const customerId = await getOrCreateStripeCustomer(stripe, {
                    clientId: body.clientId,
                    clientName: body.clientName,
                    email: body.email
                });

                const invoice = await createInvoice(stripe, customerId, {
                    clientId: body.clientId,
                    billingPeriod: body.billingPeriod
                }, body.amount);

                // Send email notification
                await sendEmailNotification(
                    body.email,
                    `Invoice Ready - ${body.billingPeriod}`,
                    `
                    <h2>Your AWS Invoice is Ready</h2>
                    <p>Amount: $${body.amount.toFixed(2)}</p>
                    <p>Period: ${body.billingPeriod}</p>
                    <p><a href="${invoice.hosted_invoice_url}">View and Pay Invoice</a></p>
                    `
                );

                return {
                    statusCode: 200,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    },
                    body: JSON.stringify({
                        invoiceId: invoice.id,
                        invoiceUrl: invoice.hosted_invoice_url,
                        amount: body.amount
                    })
                };
            }

            case 'get-payment-methods': {
                // List payment methods for customer
                const customerId = await getOrCreateStripeCustomer(stripe, {
                    clientId: body.clientId,
                    clientName: body.clientName,
                    email: body.email
                });

                const paymentMethods = await stripe.paymentMethods.list({
                    customer: customerId,
                    type: 'card'
                });

                return {
                    statusCode: 200,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    },
                    body: JSON.stringify({
                        paymentMethods: paymentMethods.data.map(pm => ({
                            id: pm.id,
                            brand: pm.card.brand,
                            last4: pm.card.last4,
                            expMonth: pm.card.exp_month,
                            expYear: pm.card.exp_year
                        }))
                    })
                };
            }

            case 'customer-portal': {
                // Generate Stripe Customer Portal URL
                const customerId = await getOrCreateStripeCustomer(stripe, {
                    clientId: body.clientId,
                    clientName: body.clientName,
                    email: body.email
                });

                const session = await stripe.billingPortal.sessions.create({
                    customer: customerId,
                    return_url: body.returnUrl || process.env.PORTAL_URL
                });

                return {
                    statusCode: 200,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    },
                    body: JSON.stringify({
                        url: session.url
                    })
                };
            }

            default:
                return {
                    statusCode: 400,
                    headers: {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    },
                    body: JSON.stringify({
                        error: "Invalid action. Supported actions: setup-payment-method, create-invoice, get-payment-methods, customer-portal"
                    })
                };
        }

    } catch (error) {
        console.error("Error:", error);
        return {
            statusCode: 500,
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            body: JSON.stringify({
                error: "Internal server error",
                message: error.message
            })
        };
    }
};
