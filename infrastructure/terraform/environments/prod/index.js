const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const tableName = process.env.DYNAMODB_TABLE;
    const partnerName = process.env.PARTNER_NAME;
    const s3Bucket = process.env.S3_BUCKET;
    
    // Handle CORS preflight requests
    const method = event.requestContext.httpMethod || event.requestContext.http?.method;
    if (method === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
            },
            body: ''
        };
    }
    
    try {
        const path = event.path || event.requestContext.path;
        const method = event.requestContext.httpMethod || event.requestContext.http?.method;
        
        // Health check endpoint (handle both /health and /prod/health)
        const pathWithoutStage = path.replace(/^\/[^/]+/, '') || path;
        if ((path === '/health' || pathWithoutStage === '/health' || path.endsWith('/health')) && method === 'GET') {
            return {
                statusCode: 200,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    status: 'healthy',
                    partner: partnerName,
                    timestamp: new Date().toISOString()
                })
            };
        }
        
        // Dashboard data endpoint (handle both /dashboard and /prod/dashboard)
        if ((path === '/dashboard' || pathWithoutStage === '/dashboard' || path.endsWith('/dashboard')) && method === 'GET') {
            // Get sample dashboard data
            const params = {
                TableName: tableName,
                Key: {
                    pk: `PARTNER#${partnerName}`,
                    sk: 'DASHBOARD#OVERVIEW'
                }
            };
            
            let dashboardData = null;
            try {
                const result = await dynamodb.get(params).promise();
                dashboardData = result.Item;
            } catch (error) {
                console.log('No existing dashboard data, creating sample data');
            }
            
            if (!dashboardData) {
                // Create sample data if none exists
                dashboardData = {
                    pk: `PARTNER#${partnerName}`,
                    sk: 'DASHBOARD#OVERVIEW',
                    metrics: {
                        totalProjects: 5,
                        activeProjects: 2,
                        completedProjects: 3,
                        totalRevenue: 150000,
                        avgProjectDuration: 45
                    },
                    lastUpdated: new Date().toISOString()
                };
                
                // Save sample data to DynamoDB
                await dynamodb.put({
                    TableName: tableName,
                    Item: dashboardData
                }).promise();
            }
            
            return {
                statusCode: 200,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(dashboardData)
            };
        }
        
        // Default response for unhandled routes
        return {
            statusCode: 404,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: 'Not Found',
                message: `Path ${path} not found`
            })
        };
        
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: 'Internal Server Error',
                message: error.message
            })
        };
    }
};