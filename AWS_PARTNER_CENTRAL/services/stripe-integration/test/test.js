const { expect } = require('chai');
const sinon = require('sinon');
const AWS = require('aws-sdk-mock');
const Stripe = require('stripe');

// Mock Stripe
const stripeMock = {
    invoices: {
        create: sinon.stub(),
        finalizeInvoice: sinon.stub()
    },
    invoiceItems: {
        create: sinon.stub()
    }
};

describe('Stripe Integration Tests', () => {
    before(() => {
        // Mock AWS services
        AWS.mock('CostExplorer', 'getCostAndUsage', {
            ResultsByTime: [{
                Groups: [{
                    Metrics: {
                        BlendedCost: { Amount: '750.00' }
                    }
                }]
            }]
        });

        AWS.mock('SNS', 'publish', {});

        AWS.mock('DynamoDB.DocumentClient', 'put', {});
    });

    after(() => {
        AWS.restore();
    });

    describe('Cost Monitor Lambda', () => {
        it('should create invoice when budget exceeded', async () => {
            // Mock cost exceeding threshold
            AWS.remock('CostExplorer', 'getCostAndUsage', {
                ResultsByTime: [{
                    Groups: [{
                        Metrics: {
                            BlendedCost: { Amount: '900.00' }
                        }
                    }]
                }]
            });

            const { handler } = require('../lambda/cost-monitor/index');

            process.env.STRIPE_SECRET_KEY = 'sk_test_mock';
            process.env.BUDGET_THRESHOLD = '800';
            process.env.SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:test';
            process.env.STRIPE_CUSTOMER_ID = 'cus_mock';

            const result = await handler({});

            expect(result.statusCode).to.equal(200);
            expect(stripeMock.invoices.create.calledOnce).to.be.true;
            expect(stripeMock.invoiceItems.create.calledOnce).to.be.true;
        });

        it('should not create invoice when under budget', async () => {
            const { handler } = require('../lambda/cost-monitor/index');

            const result = await handler({});

            expect(result.statusCode).to.equal(200);
            expect(stripeMock.invoices.create.called).to.be.false;
        });
    });

    describe('Billing Handler Lambda', () => {
        it('should handle payment succeeded webhook', async () => {
            const { handler } = require('../lambda/billing-handler/index');

            const mockEvent = {
                headers: { 'stripe-signature': 't=123,v1=mock' },
                body: JSON.stringify({
                    id: 'evt_mock',
                    type: 'invoice.payment_succeeded',
                    data: {
                        object: {
                            id: 'in_mock',
                            customer: 'cus_mock',
                            amount_due: 10000,
                            currency: 'usd'
                        }
                    }
                })
            };

            process.env.STRIPE_WEBHOOK_SECRET = 'whsec_mock';
            process.env.BILLING_TABLE_NAME = 'test-billing';
            process.env.SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:test';

            const result = await handler(mockEvent);

            expect(result.statusCode).to.equal(200);
            expect(result.body).to.equal(JSON.stringify({ received: true }));
        });

        it('should reject invalid webhook signature', async () => {
            const { handler } = require('../lambda/billing-handler/index');

            const mockEvent = {
                headers: { 'stripe-signature': 'invalid' },
                body: '{}'
            };

            const result = await handler(mockEvent);

            expect(result.statusCode).to.equal(400);
        });
    });
});