/**
 * Client Billing Portal - Cost Retrieval Lambda
 * Fetches cost and usage data from AWS Cost Explorer for specific clients
 */

const { CostExplorerClient, GetCostAndUsageCommand, GetCostForecastCommand } = require("@aws-sdk/client-cost-explorer");
const { CloudWatchClient, GetMetricStatisticsCommand } = require("@aws-sdk/client-cloudwatch");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, QueryCommand } = require("@aws-sdk/lib-dynamodb");

const ceClient = new CostExplorerClient({ region: process.env.AWS_REGION || "us-east-1" });
const cwClient = new CloudWatchClient({ region: process.env.AWS_REGION || "us-east-1" });
const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" }));

const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE || "client-billing-data";

/**
 * Get costs for a specific client using Cost Explorer API
 */
async function getClientCosts(clientOrg, startDate, endDate) {
    const params = {
        TimePeriod: {
            Start: startDate,
            End: endDate
        },
        Granularity: "DAILY",
        Metrics: ["UnblendedCost", "UsageQuantity"],
        Filter: {
            Tags: {
                Key: "ClientOrganization",
                Values: [clientOrg]
            }
        },
        GroupBy: [
            {
                Type: "TAG",
                Key: "BillingProject"
            },
            {
                Type: "SERVICE"
            }
        ]
    };

    try {
        const command = new GetCostAndUsageCommand(params);
        const response = await ceClient.send(command);
        return response.ResultsByTime;
    } catch (error) {
        console.error("Error fetching costs:", error);
        throw error;
    }
}

/**
 * Get cost forecast for next 30 days
 */
async function getCostForecast(clientOrg) {
    const today = new Date();
    const startDate = today.toISOString().split('T')[0];
    const endDate = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

    const params = {
        TimePeriod: {
            Start: startDate,
            End: endDate
        },
        Metric: "UNBLENDED_COST",
        Granularity: "MONTHLY",
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
        return response;
    } catch (error) {
        console.error("Error fetching forecast:", error);
        return null;
    }
}

/**
 * Process and summarize cost data
 */
function processCostData(resultsbyTime) {
    const summary = {
        totalCost: 0,
        byService: {},
        byProject: {},
        dailyBreakdown: []
    };

    resultsbyTime.forEach(timeEntry => {
        const date = timeEntry.TimePeriod.Start;
        let dailyCost = 0;

        timeEntry.Groups.forEach(group => {
            const cost = parseFloat(group.Metrics.UnblendedCost.Amount);
            const usage = parseFloat(group.Metrics.UsageQuantity.Amount);

            // Extract service and project from keys
            const project = group.Keys[0] || "untagged";
            const service = group.Keys[1] || "unknown";

            // Aggregate by service
            if (!summary.byService[service]) {
                summary.byService[service] = { cost: 0, usage: 0 };
            }
            summary.byService[service].cost += cost;
            summary.byService[service].usage += usage;

            // Aggregate by project
            if (!summary.byProject[project]) {
                summary.byProject[project] = { cost: 0, usage: 0 };
            }
            summary.byProject[project].cost += cost;
            summary.byProject[project].usage += usage;

            dailyCost += cost;
            summary.totalCost += cost;
        });

        summary.dailyBreakdown.push({
            date: date,
            cost: dailyCost
        });
    });

    return summary;
}

/**
 * Save billing data to DynamoDB
 */
async function saveBillingData(clientId, billingPeriod, costData) {
    const params = {
        TableName: DYNAMODB_TABLE,
        Item: {
            clientId: clientId,
            billingPeriod: billingPeriod,
            costData: costData,
            generatedAt: new Date().toISOString(),
            ttl: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1 year retention
        }
    };

    try {
        const command = new PutCommand(params);
        await ddbClient.send(command);
        console.log(`Saved billing data for ${clientId} - ${billingPeriod}`);
    } catch (error) {
        console.error("Error saving to DynamoDB:", error);
        throw error;
    }
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
    console.log("Event:", JSON.stringify(event, null, 2));

    try {
        // Parse request
        const body = event.body ? JSON.parse(event.body) : event;
        const clientOrg = body.clientOrganization || event.queryStringParameters?.clientOrganization;
        const period = body.period || event.queryStringParameters?.period || "current-month";

        if (!clientOrg) {
            return {
                statusCode: 400,
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                body: JSON.stringify({
                    error: "clientOrganization parameter is required"
                })
            };
        }

        // Calculate date range based on period
        const today = new Date();
        let startDate, endDate;

        switch (period) {
            case "current-month":
                startDate = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0];
                endDate = today.toISOString().split('T')[0];
                break;
            case "last-month":
                const lastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 1);
                startDate = lastMonth.toISOString().split('T')[0];
                endDate = new Date(today.getFullYear(), today.getMonth(), 0).toISOString().split('T')[0];
                break;
            case "last-30-days":
                startDate = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
                endDate = today.toISOString().split('T')[0];
                break;
            default:
                startDate = body.startDate;
                endDate = body.endDate;
        }

        console.log(`Fetching costs for ${clientOrg} from ${startDate} to ${endDate}`);

        // Fetch cost data
        const costResults = await getClientCosts(clientOrg, startDate, endDate);
        const costSummary = processCostData(costResults);

        // Get forecast
        const forecast = await getCostForecast(clientOrg);

        // Prepare response
        const billingData = {
            clientOrganization: clientOrg,
            period: {
                start: startDate,
                end: endDate,
                type: period
            },
            summary: costSummary,
            forecast: forecast ? {
                amount: parseFloat(forecast.Total.Amount),
                unit: forecast.Total.Unit,
                period: "next-30-days"
            } : null,
            generatedAt: new Date().toISOString()
        };

        // Save to DynamoDB
        const billingPeriod = `${startDate}_${endDate}`;
        await saveBillingData(clientOrg, billingPeriod, billingData);

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
                message: error.message
            })
        };
    }
};
