/**
 * Partner Central Sync Lambda - Placeholder Version
 *
 * This is a placeholder that sets up the infrastructure.
 * The full implementation will be available when AWS releases
 * the @aws-sdk/client-partnercentralselling package to npm.
 *
 * For now, this demonstrates the structure and can be manually
 * triggered to test the infrastructure.
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

const dynamodb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: 'us-east-1' }));
const TABLE_NAME = process.env.TABLE_NAME || 'client-billing-data';

/**
 * Main handler - placeholder that demonstrates infrastructure
 */
exports.handler = async (event) => {
    console.log('Partner Central Sync Lambda - Placeholder Version');
    console.log('Event:', JSON.stringify(event, null, 2));

    try {
        // Simulate fetching opportunities
        // In production, this would call Partner Central API
        const mockOpportunities = [
            {
                Id: 'opp-example-001',
                Customer: {
                    CompanyName: 'Example Corp',
                    Contact: { Email: 'demo@example.com' }
                },
                LifeCycle: { Stage: 'Qualified' },
                Project: {
                    Title: 'Cloud Migration',
                    ExpectedCustomerSpend: [
                        { Amount: '25000', CurrencyCode: 'USD' }
                    ]
                }
            }
        ];

        console.log(`Processing ${mockOpportunities.length} opportunities (demo mode)`);

        // Process opportunities
        const results = [];
        for (const opp of mockOpportunities) {
            const result = await processOpportunity(opp);
            results.push(result);
        }

        // Update sync state
        await updateSyncState({
            lastSyncAt: new Date().toISOString(),
            recordsSynced: mockOpportunities.length,
            syncStatus: 'success',
            mode: 'placeholder',
            message: 'Waiting for @aws-sdk/client-partnercentralselling package release'
        });

        const summary = {
            statusCode: 200,
            message: 'Placeholder sync completed - infrastructure ready',
            note: 'Full Partner Central integration available when SDK is released',
            opportunitiesProcessed: mockOpportunities.length,
            clientsCreated: results.filter(r => r.created).length,
            infrastructure: {
                dynamodbTable: TABLE_NAME,
                region: 'us-east-1',
                lambdaVersion: '1.0.0-placeholder'
            },
            nextSteps: [
                'Infrastructure is deployed and functional',
                'Lambda can be updated with real Partner Central SDK when available',
                'Use CLI tools in scripts/ directory for manual Partner Central management',
                'DynamoDB schema is ready for client data'
            ]
        };

        console.log('Summary:', JSON.stringify(summary, null, 2));

        return {
            statusCode: 200,
            body: JSON.stringify(summary)
        };

    } catch (error) {
        console.error('Error in placeholder sync:', error);

        await updateSyncState({
            lastSyncAt: new Date().toISOString(),
            syncStatus: 'failed',
            errorMessage: error.message,
            mode: 'placeholder'
        });

        return {
            statusCode: 500,
            body: JSON.stringify({
                error: error.message,
                note: 'This is a placeholder - full functionality requires Partner Central SDK'
            })
        };
    }
};

/**
 * Process a single opportunity
 */
async function processOpportunity(opp) {
    const companyName = opp.Customer?.CompanyName || 'Unknown';
    const clientId = companyName.toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '');

    console.log(`Processing: ${companyName} (${clientId})`);

    // Check if client exists
    const existing = await getClient(clientId);

    // Use existing table schema: clientId as hash key, billingPeriod as range key
    const clientData = {
        clientId: clientId,
        billingPeriod: 'PROFILE',  // Use billingPeriod for client profile records
        clientName: companyName,
        clientOrganization: companyName.replace(/\s+/g, '-'),
        partnerCentralOpportunityId: opp.Id,
        partnerCentralStage: opp.LifeCycle?.Stage || 'Unknown',
        partnerCentralRawData: opp,
        expectedMonthlySpend: parseFloat(
            opp.Project?.ExpectedCustomerSpend?.[0]?.Amount || '0'
        ),
        currency: opp.Project?.ExpectedCustomerSpend?.[0]?.CurrencyCode || 'USD',
        contactEmail: opp.Customer?.Contact?.Email || `billing@${clientId}.com`,
        lastSyncedAt: new Date().toISOString(),
        syncMode: 'placeholder'
    };

    if (existing) {
        // In placeholder mode, just log (don't update)
        console.log(`Client exists: ${clientId} - would update in production mode`);
        return { updated: true, clientId, mode: 'simulated' };
    } else {
        // Create new client record
        clientData.status = 'prospect';
        clientData.createdAt = new Date().toISOString();
        clientData.createdBy = 'partner-central-sync-placeholder';

        await dynamodb.send(new PutCommand({
            TableName: TABLE_NAME,
            Item: clientData
        }));

        console.log(`Created client: ${clientId}`);
        return { created: true, clientId };
    }
}

/**
 * Get client from DynamoDB
 * Uses clientId and billingPeriod='PROFILE' to match existing table schema
 */
async function getClient(clientId) {
    try {
        const result = await dynamodb.send(new GetCommand({
            TableName: TABLE_NAME,
            Key: {
                clientId: clientId,
                billingPeriod: 'PROFILE'
            }
        }));
        return result.Item;
    } catch (error) {
        console.error(`Error getting client ${clientId}:`, error);
        return null;
    }
}

/**
 * Update sync state
 * Uses clientId and billingPeriod keys to match existing table schema
 */
async function updateSyncState(state) {
    await dynamodb.send(new PutCommand({
        TableName: TABLE_NAME,
        Item: {
            clientId: 'SYNC',
            billingPeriod: 'OPPORTUNITIES',
            ...state
        }
    }));
}
