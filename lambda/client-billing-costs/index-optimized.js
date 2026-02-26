/**
 * Client Billing Portal - Cost Retrieval Lambda (OPTIMIZED)
 * Fetches cost and usage data from AWS Cost Explorer for specific clients
 * 
 * COST OPTIMIZATIONS IMPLEMENTED:
 * 1. DynamoDB caching (24 hours)
 * 2. Reduced granularity (MONTHLY for historical data)
 * 3. Limited date ranges (current month + last month only)
 * 4. Batch processing for multiple clients
 * 5. Removed expensive forecast calls except when specifically requested
 */

const { CostExplorerClient, GetCostAndUsageCommand, GetCostForecastCommand } = require("@aws-sdk/client-cost-explorer");
const { CloudWatchClient, GetMetricStatisticsCommand } = require("@aws-sdk/client-cloudwatch");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, QueryCommand, GetCommand } = require("@aws-sdk/lib-dynamodb");

const ceClient = new CostExplorerClient({ region: process.env.AWS_REGION || "us-east-1" });
const cwClient = new CloudWatchClient({ region: process.env.AWS_REGION || "us-east-1" });
const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" }));

const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE || "client-billing-data";
const CACHE_TABLE = process.env.CACHE_TABLE || `${DYNAMODB_TABLE}-cache`;

// Cache configuration
const CACHE_TTL_HOURS = 24;
const CACHE_TTL_SECONDS = CACHE_TTL_HOURS * 60 * 60;
const ENABLE_FORECASTING = process.env.ENABLE_FORECASTING === 'true'; // Default: disabled

/**
 * Enhanced cache functions
 */
async function getCachedData(cacheKey) {
    try {
        const result = await ddbClient.send(new GetCommand({
            TableName: CACHE_TABLE,
            Key: { cache_key: cacheKey }
        }));

        if (result.Item) {
            const now = Math.floor(Date.now() / 1000);
            if (result.Item.expires_at > now) {
                console.log(`Cache hit for: ${cacheKey}`);
                return result.Item.data;
            } else {
                console.log(`Cache expired for: ${cacheKey}`);
            }
        }
        
        console.log(`Cache miss for: ${cacheKey}`);
        return null;
    } catch (error) {
        console.error('Cache read error:', error);
        return null;
    }
}

async function setCachedData(cacheKey, data) {
    try {
        const expiresAt = Math.floor(Date.now() / 1000) + CACHE_TTL_SECONDS;
        
        await ddbClient.send(new PutCommand({
            TableName: CACHE_TABLE,
            Item: {
                cache_key: cacheKey,
                data: data,
                expires_at: expiresAt,
                created_at: new Date().toISOString(),
                ttl: expiresAt
            }
        }));
        
        console.log(`Cached data for: ${cacheKey}`);
    } catch (error) {
        console.error('Cache write error:', error);
    }
}

function generateCacheKey(prefix, params) {
    const paramString = JSON.stringify(params, Object.keys(params).sort());
    const hash = require('crypto').createHash('md5').update(paramString).digest('hex');
    return `${prefix}:${hash}`;
}

/**
 * Get costs for a specific client using Cost Explorer API (OPTIMIZED)
 */
async function getClientCostsOptimized(clientOrg, period) {
    const { startDate, endDate, granularity } = calculateOptimalDateRange(period);
    
    // Generate cache key
    const cacheParams = { clientOrg, startDate, endDate, granularity };
    const cacheKey = generateCacheKey('client_costs', cacheParams);
    
    // Check cache first
    const cachedData = await getCachedData(cacheKey);
    if (cachedData) {
        return {
            ...cachedData,
            cached: true,
            cache_timestamp: new Date().toISOString()
        };
    }
    
    console.log(`Making Cost Explorer API call for ${clientOrg}: ${startDate} to ${endDate}, granularity: ${granularity}`);
    
    const params = {
        TimePeriod: {
            Start: startDate,
            End: endDate
        },
        Granularity: granularity,
        Metrics: ["UnblendedCost"], // Removed UsageQuantity to reduce response size
        Filter: {
            Tags: {
                Key: "ClientOrganization",
                Values: [clientOrg]
            }
        },
        GroupBy: [
            {
                Type: "SERVICE" // Removed TAG grouping to reduce complexity
            }
        ]
    };

    try {
        const command = new GetCostAndUsageCommand(params);
        const response = await ceClient.send(command);
        
        const result = {
            resultsByTime: response.ResultsByTime,
            period: { startDate, endDate, granularity },
            cached: false,
            optimization_note: `Optimized: ${granularity} granularity, service-only grouping`
        };
        
        // Cache the result
        await setCachedData(cacheKey, result);
        
        return result;
    } catch (error) {
        console.error("Error fetching costs:", error);
        throw error;
    }
}

/**
 * Calculate optimal date range and granularity based on period
 */
function calculateOptimalDateRange(period) {
    const today = new Date();
    let startDate, endDate, granularity;

    switch (period) {
        case "current-month":
            startDate = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0];
            endDate = today.toISOString().split('T')[0];
            granularity = "DAILY"; // Current month gets daily detail
            break;
        case "last-month":
            const lastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 1);
            startDate = lastMonth.toISOString().split('T')[0];
            endDate = new Date(today.getFullYear(), today.getMonth(), 0).toISOString().split('T')[0];
            granularity = "MONTHLY"; // Historical data uses monthly
            break;
        case "last-30-days":
            // Optimize to current month + last month only
            startDate = new Date(today.getFullYear(), today.getMonth() - 1, 1).toISOString().split('T')[0];
            endDate = today.toISOString().split('T')[0];
            granularity = "MONTHLY"; // Use monthly for multi-month ranges
            break;
        default:
            // Custom date range - use monthly for cost efficiency
            startDate = period.startDate;
            endDate = period.endDate;
            granularity = "MONTHLY";
    }

    return { startDate, endDate, granularity };
}

/**
 * Get cost forecast for next 30 days (OPTIMIZED - only when enabled)
 */
async function getCostForecastOptimized(clientOrg) {
    if (!ENABLE_FORECASTING) {
        console.log('Forecasting disabled for cost optimization');
        return null;
    }
    
    const today = new Date();
    const startDate = today.toISOString().split('T')[0];
    const endDate = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

    // Check cache for forecast
    const cacheKey = generateCacheKey('forecast', { clientOrg, startDate, endDate });
    const cachedForecast = await getCachedData(cacheKey);
    if (cachedForecast) {
        return cachedForecast;
    }

    const params = {
        TimePeriod: {
            Start: startDate,
            End: endDate
        },
        Metric: "UNBLENDED_COST",
        Granularity: "MONTHLY", // Use monthly for forecasts
        Filter: {
            Tags: {
                Key: "ClientOrganization",
                Values: [clientOrg]
            }
        }
    };

    try {
        const command = new GetCostForecastCommand(params);
        const response = await ceClient.send(command);
        
        // Cache the forecast
        await setCachedData(cacheKey, response);
        
        return response;
    } catch (error) {
        console.error("Error fetching forecast:", error);
        return null;
    }
}

/**
 * Process and summarize cost data (OPTIMIZED)
 */
function processCostDataOptimized(resultsbyTime, granularity) {
    const summary = {
        totalCost: 0,
        byService: {},
        dailyBreakdown: [],
        optimization: {
            granularity,
            dataPoints: 0,
            cachingEnabled: true
        }
    };

    if (!resultsbyTime) {
        return summary;
    }

    resultsbyTime.forEach(timeEntry => {
        const date = timeEntry.TimePeriod.Start;
        let periodCost = 0;

        timeEntry.Groups.forEach(group => {
            const cost = parseFloat(group.Metrics.UnblendedCost.Amount) || 0;
            const service = group.Keys[0] || "unknown";

            periodCost += cost;
            summary.optimization.dataPoints++;

            // Aggregate by service
            if (!summary.byService[service]) {
                summary.byService[service] = { cost: 0 };
            }
            summary.byService[service].cost += cost;

            summary.totalCost += cost;
        });

        summary.dailyBreakdown.push({
            date: date,
            cost: periodCost
        });
    });

    return summary;
}

/**
 * Batch process multiple clients (NEW FEATURE)
 */
async function batchProcessClients(clientOrgs, period) {
    console.log(`Batch processing ${clientOrgs.length} clients`);
    
    const results = [];
    const batchSize = 3; // Process 3 clients at a time to avoid rate limits
    
    for (let i = 0; i < clientOrgs.length; i += batchSize) {
        const batch = clientOrgs.slice(i, i + batchSize);
        
        const batchPromises = batch.map(async (clientOrg) => {
            try {
                const costResults = await getClientCostsOptimized(clientOrg, period);
                const costSummary = processCostDataOptimized(costResults.resultsByTime, costResults.period.granularity);
                
                return {
                    clientOrganization: clientOrg,
                    summary: costSummary,
                    period: costResults.period,
                    cached: costResults.cached,
                    success: true
                };
            } catch (error) {
                console.error(`Error processing ${clientOrg}:`, error);
                return {
                    clientOrganization: clientOrg,
                    error: error.message,
                    success: false
                };
            }
        });
        
        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults);
        
        // Add small delay between batches
        if (i + batchSize < clientOrgs.length) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
    
    return results;
}

/**
 * Save billing data to DynamoDB (OPTIMIZED)
 */
async function saveBillingDataOptimized(clientId, billingPeriod, costData) {
    const params = {
        TableName: DYNAMODB_TABLE,
        Item: {
            clientId: clientId,
            billingPeriod: billingPeriod,
            costData: costData,
            generatedAt: new Date().toISOString(),
            ttl: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60), // 1 year retention
            optimized: true,
            version: "2.0"
        }
    };

    try {
        const command = new PutCommand(params);
        await ddbClient.send(command);
        console.log(`Saved optimized billing data for ${clientId} - ${billingPeriod}`);
    } catch (error) {
        console.error("Error saving to DynamoDB:", error);
        throw error;
    }
}

/**
 * Lambda handler (ENHANCED)
 */
exports.handler = async (event) => {
    console.log("Event:", JSON.stringify(event, null, 2));

    try {
        // Parse request
        const body = event.body ? JSON.parse(event.body) : event;
        const clientOrg = body.clientOrganization || event.queryStringParameters?.clientOrganization;
        const clientOrgs = body.clientOrganizations; // Support for batch processing
        const period = body.period || event.queryStringParameters?.period || "current-month";
        const includeForecast = body.includeForecast === true; // Explicit opt-in for forecasting

        // Handle batch processing
        if (clientOrgs && Array.isArray(clientOrgs)) {
            console.log(`Batch processing request for ${clientOrgs.length} clients`);
            
            const batchResults = await batchProcessClients(clientOrgs, period);
            
            return {
                statusCode: 200,
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Headers": "Content-Type,Authorization",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
                },
                body: JSON.stringify({
                    batchResults,
                    totalClients: clientOrgs.length,
                    successfulClients: batchResults.filter(r => r.success).length,
                    optimization: {
                        cachingEnabled: true,
                        forecastingEnabled: ENABLE_FORECASTING,
                        batchProcessing: true
                    },
                    generatedAt: new Date().toISOString()
                }, null, 2)
            };
        }

        // Single client processing
        if (!clientOrg) {
            return {
                statusCode: 400,
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                body: JSON.stringify({
                    error: "clientOrganization parameter is required (or use clientOrganizations array for batch processing)"
                })
            };
        }

        console.log(`Processing single client: ${clientOrg}, period: ${period}`);

        // Fetch cost data
        const costResults = await getClientCostsOptimized(clientOrg, period);
        const costSummary = processCostDataOptimized(costResults.resultsByTime, costResults.period.granularity);

        // Get forecast only if explicitly requested
        let forecast = null;
        if (includeForecast) {
            forecast = await getCostForecastOptimized(clientOrg);
        }

        // Prepare response
        const billingData = {
            clientOrganization: clientOrg,
            period: costResults.period,
            summary: costSummary,
            forecast: forecast ? {
                amount: parseFloat(forecast.Total?.Amount || 0),
                unit: forecast.Total?.Unit || "USD",
                period: "next-30-days",
                cached: forecast.cached || false
            } : null,
            cached: costResults.cached,
            optimization: {
                cachingEnabled: true,
                forecastingEnabled: ENABLE_FORECASTING && includeForecast,
                costReductionFeatures: [
                    "DynamoDB caching (24h)",
                    "Optimized granularity",
                    "Reduced GroupBy dimensions",
                    "Removed UsageQuantity metric",
                    "Optional forecasting"
                ]
            },
            generatedAt: new Date().toISOString()
        };

        // Save to DynamoDB
        const billingPeriod = `${costResults.period.startDate}_${costResults.period.endDate}`;
        await saveBillingDataOptimized(clientOrg, billingPeriod, billingData);

        // Return response
        return {
            statusCode: 200,
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,Authorization",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
            },
            body: JSON.stringify(billingData, null, 2)
        };

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
                message: error.message,
                optimization_note: "This function has been optimized to reduce Cost Explorer API usage"
            })
        };
    }
};