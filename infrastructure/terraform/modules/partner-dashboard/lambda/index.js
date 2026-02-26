const AWS = require('aws-sdk');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const cloudwatch = new AWS.CloudWatch();
const ec2 = new AWS.EC2();
const rds = new AWS.RDS();
const s3 = new AWS.S3();
const costexplorer = new AWS.CostExplorer();

// Environment variables
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;
const PARTNER_NAME = process.env.PARTNER_NAME;
const S3_BUCKET = process.env.S3_BUCKET;

// CORS headers
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // Handle preflight CORS requests
        if (event.requestContext.http.method === 'OPTIONS') {
            return {
                statusCode: 200,
                headers: corsHeaders
            };
        }

        const { path, httpMethod } = event.requestContext.http;
        const pathParts = path.split('/').filter(p => p);
        
        let response;

        switch (pathParts[0]) {
            case 'metrics':
                response = await handleMetrics(event);
                break;
            case 'resources':
                response = await handleResources(event);
                break;
            case 'dashboard':
                response = await handleDashboard(event);
                break;
            case 'config':
                response = await handleConfig(event);
                break;
            case 'health':
                response = await handleHealth(event);
                break;
            case 'costs':
                response = await handleCosts(event);
                break;
            default:
                response = {
                    statusCode: 404,
                    body: JSON.stringify({ error: 'Endpoint not found' })
                };
        }

        return {
            ...response,
            headers: {
                ...corsHeaders,
                ...response.headers
            }
        };

    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: error.message 
            })
        };
    }
};

// Handle metrics endpoints
async function handleMetrics(event) {
    const { httpMethod } = event.requestContext.http;
    
    if (httpMethod === 'GET') {
        const metrics = await getPartnerMetrics();
        return {
            statusCode: 200,
            body: JSON.stringify(metrics)
        };
    }
    
    return {
        statusCode: 405,
        body: JSON.stringify({ error: 'Method not allowed' })
    };
}

// Handle resources endpoints  
async function handleResources(event) {
    const { httpMethod } = event.requestContext.http;
    
    if (httpMethod === 'GET') {
        const resources = await getPartnerResources();
        return {
            statusCode: 200,
            body: JSON.stringify(resources)
        };
    }
    
    return {
        statusCode: 405,
        body: JSON.stringify({ error: 'Method not allowed' })
    };
}

// Handle dashboard configuration
async function handleDashboard(event) {
    const { httpMethod } = event.requestContext.http;
    
    if (httpMethod === 'GET') {
        const config = await getDashboardConfig();
        return {
            statusCode: 200,
            body: JSON.stringify(config)
        };
    }
    
    if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        await saveDashboardConfig(body);
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Configuration saved' })
        };
    }
    
    return {
        statusCode: 405,
        body: JSON.stringify({ error: 'Method not allowed' })
    };
}

// Handle config endpoints
async function handleConfig(event) {
    const config = {
        partner: PARTNER_NAME,
        endpoints: {
            metrics: '/metrics',
            resources: '/resources', 
            dashboard: '/dashboard',
            costs: '/costs'
        },
        version: '1.0.0'
    };
    
    return {
        statusCode: 200,
        body: JSON.stringify(config)
    };
}

// Handle cost and usage endpoints
async function handleCosts(event) {
    const { httpMethod } = event.requestContext.http;
    
    if (httpMethod === 'GET') {
        const costs = await getCompanyCosts();
        return {
            statusCode: 200,
            body: JSON.stringify(costs)
        };
    }
    
    return {
        statusCode: 405,
        body: JSON.stringify({ error: 'Method not allowed' })
    };
}

// Health check endpoint
async function handleHealth(event) {
    const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        partner: PARTNER_NAME,
        services: {
            dynamodb: 'ok',
            cloudwatch: 'ok',
            s3: 'ok'
        }
    };
    
    return {
        statusCode: 200,
        body: JSON.stringify(health)
    };
}

// Get partner-specific metrics from CloudWatch
async function getPartnerMetrics() {
    const endTime = new Date();
    const startTime = new Date(endTime.getTime() - 24 * 60 * 60 * 1000); // 24 hours ago
    
    try {
        // Get Lambda metrics
        const lambdaMetrics = await cloudwatch.getMetricStatistics({
            Namespace: 'AWS/Lambda',
            MetricName: 'Invocations',
            Dimensions: [{
                Name: 'FunctionName',
                Value: `${PARTNER_NAME}-dashboard-api`
            }],
            StartTime: startTime,
            EndTime: endTime,
            Period: 3600,
            Statistics: ['Sum']
        }).promise();

        // Get API Gateway metrics
        const apiMetrics = await cloudwatch.getMetricStatistics({
            Namespace: 'AWS/ApiGatewayV2',
            MetricName: 'Count',
            StartTime: startTime,
            EndTime: endTime,
            Period: 3600,
            Statistics: ['Sum']
        }).promise();

        return {
            lambda: {
                invocations: lambdaMetrics.Datapoints || []
            },
            api: {
                requests: apiMetrics.Datapoints || []
            },
            timestamp: new Date().toISOString()
        };
        
    } catch (error) {
        console.error('Error getting metrics:', error);
        return {
            error: 'Failed to retrieve metrics',
            timestamp: new Date().toISOString()
        };
    }
}

// Get partner-tagged resources
async function getPartnerResources() {
    try {
        const resources = {
            ec2: [],
            rds: [],
            s3: []
        };

        // Get EC2 instances with partner tag
        try {
            const ec2Response = await ec2.describeInstances({
                Filters: [{
                    Name: 'tag:Partner',
                    Values: [PARTNER_NAME]
                }]
            }).promise();

            ec2Response.Reservations.forEach(reservation => {
                reservation.Instances.forEach(instance => {
                    resources.ec2.push({
                        id: instance.InstanceId,
                        type: instance.InstanceType,
                        state: instance.State.Name,
                        name: instance.Tags?.find(tag => tag.Key === 'Name')?.Value || 'Unnamed'
                    });
                });
            });
        } catch (error) {
            console.error('Error getting EC2 instances:', error);
        }

        // Get RDS instances with partner tag
        try {
            const rdsResponse = await rds.describeDBInstances().promise();
            
            for (const instance of rdsResponse.DBInstances) {
                const tags = await rds.listTagsForResource({
                    ResourceName: instance.DBInstanceArn
                }).promise();
                
                const hasPartnerTag = tags.TagList.some(tag => 
                    tag.Key === 'Partner' && tag.Value === PARTNER_NAME
                );
                
                if (hasPartnerTag) {
                    resources.rds.push({
                        id: instance.DBInstanceIdentifier,
                        engine: instance.Engine,
                        status: instance.DBInstanceStatus,
                        class: instance.DBInstanceClass
                    });
                }
            }
        } catch (error) {
            console.error('Error getting RDS instances:', error);
        }

        return {
            resources,
            count: resources.ec2.length + resources.rds.length + resources.s3.length,
            timestamp: new Date().toISOString()
        };
        
    } catch (error) {
        console.error('Error getting resources:', error);
        return {
            error: 'Failed to retrieve resources',
            timestamp: new Date().toISOString()
        };
    }
}

// Get dashboard configuration from DynamoDB
async function getDashboardConfig() {
    try {
        const result = await dynamodb.get({
            TableName: DYNAMODB_TABLE,
            Key: {
                pk: `PARTNER#${PARTNER_NAME}`,
                sk: 'CONFIG#DASHBOARD'
            }
        }).promise();
        
        return result.Item?.config || {
            theme: 'light',
            widgets: ['metrics', 'resources', 'alerts'],
            refreshInterval: 300000 // 5 minutes
        };
        
    } catch (error) {
        console.error('Error getting dashboard config:', error);
        return {
            theme: 'light',
            widgets: ['metrics', 'resources', 'alerts'],
            refreshInterval: 300000
        };
    }
}

// Save dashboard configuration to DynamoDB
async function saveDashboardConfig(config) {
    try {
        await dynamodb.put({
            TableName: DYNAMODB_TABLE,
            Item: {
                pk: `PARTNER#${PARTNER_NAME}`,
                sk: 'CONFIG#DASHBOARD',
                config,
                updatedAt: new Date().toISOString()
            }
        }).promise();
        
    } catch (error) {
        console.error('Error saving dashboard config:', error);
        throw new Error('Failed to save configuration');
    }
}

// Get cost and usage data for specific companies
async function getCompanyCosts() {
    const endTime = new Date();
    const startTime = new Date(endTime.getTime() - 30 * 24 * 60 * 60 * 1000); // 30 days ago
    
    // Company-specific identifiers for filtering
    const targetCompanies = [
        'minute-man-press',
        'minuteman-press', 
        'steve-heaney-investment',
        'steve-heaney-investment-hub',
        'investment-hub'
    ];
    
    try {
        // Get cost and usage with tag filters for specific companies
        const costData = await costexplorer.getCostAndUsage({
            TimePeriod: {
                Start: startTime.toISOString().split('T')[0],
                End: endTime.toISOString().split('T')[0]
            },
            Granularity: 'DAILY',
            Metrics: ['BlendedCost', 'UsageQuantity'],
            GroupBy: [
                {
                    Type: 'TAG',
                    Key: 'Company'
                },
                {
                    Type: 'TAG', 
                    Key: 'Project'
                },
                {
                    Type: 'SERVICE'
                }
            ],
            Filter: {
                Or: [
                    {
                        Tags: {
                            Key: 'Company',
                            Values: targetCompanies,
                            MatchOptions: ['EQUALS', 'STARTS_WITH']
                        }
                    },
                    {
                        Tags: {
                            Key: 'Project',
                            Values: targetCompanies,
                            MatchOptions: ['EQUALS', 'STARTS_WITH']
                        }
                    },
                    {
                        Tags: {
                            Key: 'Partner',
                            Values: [PARTNER_NAME]
                        }
                    }
                ]
            }
        }).promise();
        
        // Get dimension values for company breakdown
        const dimensions = await costexplorer.getDimensionValues({
            TimePeriod: {
                Start: startTime.toISOString().split('T')[0],
                End: endTime.toISOString().split('T')[0]
            },
            Dimension: 'SERVICE',
            Context: 'COST_AND_USAGE',
            Filter: {
                Tags: {
                    Key: 'Partner',
                    Values: [PARTNER_NAME]
                }
            }
        }).promise();
        
        // Process and summarize cost data
        const summary = processCostData(costData, targetCompanies);
        
        return {
            period: {
                start: startTime.toISOString().split('T')[0],
                end: endTime.toISOString().split('T')[0]
            },
            companies: targetCompanies,
            summary,
            rawData: costData.ResultsByTime || [],
            services: dimensions.DimensionValues || [],
            timestamp: new Date().toISOString()
        };
        
    } catch (error) {
        console.error('Error getting cost data:', error);
        return {
            error: 'Failed to retrieve cost data',
            message: error.message,
            companies: targetCompanies,
            timestamp: new Date().toISOString()
        };
    }
}

// Process cost data and create summary
function processCostData(costData, targetCompanies) {
    const summary = {
        totalCost: 0,
        dailyCosts: [],
        serviceBreakdown: {},
        companyBreakdown: {}
    };
    
    if (!costData.ResultsByTime) {
        return summary;
    }
    
    costData.ResultsByTime.forEach(result => {
        const date = result.TimePeriod.Start;
        let dailyTotal = 0;
        
        result.Groups.forEach(group => {
            const cost = parseFloat(group.Metrics.BlendedCost.Amount || 0);
            const usage = parseFloat(group.Metrics.UsageQuantity.Amount || 0);
            
            dailyTotal += cost;
            
            // Extract company and service from keys
            const keys = group.Keys || [];
            const company = keys.find(key => 
                targetCompanies.some(tc => key.toLowerCase().includes(tc))
            ) || 'unknown';
            const service = keys[keys.length - 1] || 'unknown';
            
            // Update service breakdown
            if (!summary.serviceBreakdown[service]) {
                summary.serviceBreakdown[service] = 0;
            }
            summary.serviceBreakdown[service] += cost;
            
            // Update company breakdown
            if (!summary.companyBreakdown[company]) {
                summary.companyBreakdown[company] = 0;
            }
            summary.companyBreakdown[company] += cost;
        });
        
        summary.dailyCosts.push({
            date,
            cost: dailyTotal
        });
        
        summary.totalCost += dailyTotal;
    });
    
    return summary;
}
