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
const COST_CACHE_TABLE = process.env.COST_CACHE_TABLE || `${DYNAMODB_TABLE}-cost-cache`;

// Cache configuration
const CACHE_TTL_HOURS = 24; // Cache for 24 hours
const CACHE_TTL_SECONDS = CACHE_TTL_HOURS * 60 * 60;

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

// Enhanced cost cache functions
async function getCachedCostData(cacheKey) {
    try {
        const result = await dynamodb.get({
            TableName: COST_CACHE_TABLE,
            Key: { cache_key: cacheKey }
        }).promise();

        if (result.Item) {
            const now = Math.floor(Date.now() / 1000);
            if (result.Item.expires_at > now) {
                console.log(`Cache hit for key: ${cacheKey}`);
                return result.Item.data;
            } else {
                console.log(`Cache expired for key: ${cacheKey}`);
                // Clean up expired entry
                await dynamodb.delete({
                    TableName: COST_CACHE_TABLE,
                    Key: { cache_key: cacheKey }
                }).promise();
            }
        }
        
        console.log(`Cache miss for key: ${cacheKey}`);
        return null;
    } catch (error) {
        console.error('Cache read error:', error);
        return null; // Graceful fallback - proceed without cache
    }
}

async function setCachedCostData(cacheKey, data) {
    try {
        const expiresAt = Math.floor(Date.now() / 1000) + CACHE_TTL_SECONDS;
        
        await dynamodb.put({
            TableName: COST_CACHE_TABLE,
            Item: {
                cache_key: cacheKey,
                data: data,
                expires_at: expiresAt,
                created_at: new Date().toISOString(),
                ttl: expiresAt // DynamoDB TTL attribute
            }
        }).promise();
        
        console.log(`Cached data for key: ${cacheKey}, expires: ${new Date(expiresAt * 1000).toISOString()}`);
    } catch (error) {
        console.error('Cache write error:', error);
        // Don't fail the request if cache write fails
    }
}

// Generate cache key based on parameters
function generateCacheKey(prefix, params) {
    const paramString = JSON.stringify(params, Object.keys(params).sort());
    const hash = require('crypto').createHash('md5').update(paramString).digest('hex');
    return `${prefix}:${hash}`;
}

// Handle cost and usage endpoints with caching
async function handleCosts(event) {
    const { httpMethod } = event.requestContext.http;
    
    if (httpMethod === 'GET') {
        const costs = await getCompanyCostsWithCache();
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

// Enhanced getCompanyCosts with caching and optimization
async function getCompanyCostsWithCache() {
    const endTime = new Date();
    const startTime = new Date(endTime.getTime() - 7 * 24 * 60 * 60 * 1000); // Reduced to 7 days instead of 30
    
    // Company-specific identifiers for filtering
    const targetCompanies = [
        'minute-man-press',
        'minuteman-press', 
        'steve-heaney-investment',
        'steve-heaney-investment-hub',
        'investment-hub'
    ];
    
    // Generate cache key based on date range and companies
    const cacheParams = {
        startDate: startTime.toISOString().split('T')[0],
        endDate: endTime.toISOString().split('T')[0],
        companies: targetCompanies,
        partner: PARTNER_NAME
    };
    const cacheKey = generateCacheKey('company_costs', cacheParams);
    
    // Try to get from cache first
    const cachedData = await getCachedCostData(cacheKey);
    if (cachedData) {
        return {
            ...cachedData,
            cached: true,
            cache_timestamp: new Date().toISOString()
        };
    }
    
    try {
        // Optimized Cost Explorer call with MONTHLY granularity for older data
        const isCurrentMonth = startTime.getMonth() === endTime.getMonth();
        const granularity = isCurrentMonth ? 'DAILY' : 'MONTHLY'; // Use MONTHLY for historical data
        
        console.log(`Making Cost Explorer API call with granularity: ${granularity}`);
        
        // Single optimized Cost Explorer call
        const costData = await costexplorer.getCostAndUsage({
            TimePeriod: {
                Start: startTime.toISOString().split('T')[0],
                End: endTime.toISOString().split('T')[0]
            },
            Granularity: granularity,
            Metrics: ['BlendedCost'], // Removed UsageQuantity to reduce response size
            GroupBy: [
                {
                    Type: 'TAG',
                    Key: 'Company'
                },
                {
                    Type: 'SERVICE' // Removed Project grouping to reduce API complexity
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
                            Key: 'Partner',
                            Values: [PARTNER_NAME]
                        }
                    }
                ]
            }
        }).promise();
        
        // Process and summarize cost data
        const summary = processCostDataOptimized(costData, targetCompanies);
        
        const result = {
            period: {
                start: startTime.toISOString().split('T')[0],
                end: endTime.toISOString().split('T')[0],
                granularity: granularity
            },
            companies: targetCompanies,
            summary,
            cached: false,
            timestamp: new Date().toISOString(),
            optimization_note: `Reduced to 7-day window, ${granularity} granularity for cost optimization`
        };
        
        // Cache the result
        await setCachedCostData(cacheKey, result);
        
        return result;
        
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

// Optimized cost data processing
function processCostDataOptimized(costData, targetCompanies) {
    const summary = {
        totalCost: 0,
        dailyCosts: [],
        serviceBreakdown: {},
        companyBreakdown: {},
        optimization: {
            dataPoints: 0,
            apiCallsSaved: 'Cached for 24 hours'
        }
    };
    
    if (!costData.ResultsByTime) {
        return summary;
    }
    
    costData.ResultsByTime.forEach(result => {
        const date = result.TimePeriod.Start;
        let dailyTotal = 0;
        
        result.Groups.forEach(group => {
            const cost = parseFloat(group.Metrics.BlendedCost.Amount || 0);
            dailyTotal += cost;
            summary.optimization.dataPoints++;
            
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

// Handle metrics endpoints (unchanged)
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

// Handle resources endpoints (unchanged)
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

// Handle dashboard configuration (unchanged)
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

// Handle config endpoints (unchanged)
async function handleConfig(event) {
    const config = {
        partner: PARTNER_NAME,
        endpoints: {
            metrics: '/metrics',
            resources: '/resources', 
            dashboard: '/dashboard',
            costs: '/costs'
        },
        version: '1.0.0-optimized',
        caching: {
            enabled: true,
            ttl_hours: CACHE_TTL_HOURS
        }
    };
    
    return {
        statusCode: 200,
        body: JSON.stringify(config)
    };
}

// Health check endpoint (enhanced)
async function handleHealth(event) {
    const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        partner: PARTNER_NAME,
        services: {
            dynamodb: 'ok',
            cloudwatch: 'ok',
            s3: 'ok',
            costexplorer_cache: 'enabled'
        },
        optimization: {
            caching_enabled: true,
            cache_ttl_hours: CACHE_TTL_HOURS,
            cost_reduction_features: [
                'DynamoDB caching (24h)',
                'Reduced date ranges (7 days vs 30 days)', 
                'Optimized granularity (MONTHLY for historical)',
                'Reduced GroupBy dimensions',
                'Removed UsageQuantity metric'
            ]
        }
    };
    
    return {
        statusCode: 200,
        body: JSON.stringify(health)
    };
}

// Remaining functions unchanged...
async function getPartnerMetrics() {
    // Implementation unchanged from original
    const endTime = new Date();
    const startTime = new Date(endTime.getTime() - 24 * 60 * 60 * 1000);
    
    try {
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

async function getPartnerResources() {
    // Implementation unchanged from original
    try {
        const resources = {
            ec2: [],
            rds: [],
            s3: []
        };

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