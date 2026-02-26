# Lambda Functions for AI Nexus backend services

# Lambda function for User Data operations
resource "aws_lambda_function" "ai_nexus_user_data_lambda" {
  filename         = "lambda/ai-nexus-user-data.zip"
  function_name    = "${var.project_name}-${var.environment}-ai-nexus-user-data"
  role            = aws_iam_role.ai_nexus_lambda_dynamodb_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30

  # Create a placeholder zip file if it doesn't exist
  depends_on = [data.archive_file.ai_nexus_user_data_lambda_zip]

  environment {
    variables = {
      USER_DATA_TABLE_NAME = aws_dynamodb_table.ai_nexus_user_data.name
      APP_STATE_TABLE_NAME = aws_dynamodb_table.ai_nexus_app_state.name
      REGION = var.aws_region
      STAGE = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-user-data-lambda"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# Lambda function for Files operations
resource "aws_lambda_function" "ai_nexus_files_lambda" {
  filename         = "lambda/ai-nexus-files.zip"
  function_name    = "${var.project_name}-${var.environment}-ai-nexus-files"
  role            = aws_iam_role.ai_nexus_lambda_s3_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 60

  depends_on = [data.archive_file.ai_nexus_files_lambda_zip]

  environment {
    variables = {
      FILES_TABLE_NAME = aws_dynamodb_table.ai_nexus_files.name
      S3_BUCKET_NAME = aws_s3_bucket.ai_nexus_uploads.bucket
      REGION = var.aws_region
      STAGE = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-files-lambda"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# Lambda function for Sessions operations
resource "aws_lambda_function" "ai_nexus_sessions_lambda" {
  filename         = "lambda/ai-nexus-sessions.zip"
  function_name    = "${var.project_name}-${var.environment}-ai-nexus-sessions"
  role            = aws_iam_role.ai_nexus_lambda_dynamodb_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30

  depends_on = [data.archive_file.ai_nexus_sessions_lambda_zip]

  environment {
    variables = {
      SESSIONS_TABLE_NAME = aws_dynamodb_table.ai_nexus_sessions.name
      REGION = var.aws_region
      STAGE = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-sessions-lambda"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# IAM role for Lambda functions to access S3
resource "aws_iam_role" "ai_nexus_lambda_s3_role" {
  name = "${var.project_name}-${var.environment}-ai-nexus-lambda-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-lambda-s3-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for Lambda to access S3 and DynamoDB
resource "aws_iam_policy" "ai_nexus_lambda_s3_policy" {
  name        = "${var.project_name}-${var.environment}-ai-nexus-lambda-s3-policy"
  description = "Policy for Lambda functions to access S3 and DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.ai_nexus_uploads.arn,
          "${aws_s3_bucket.ai_nexus_uploads.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.ai_nexus_files.arn,
          "${aws_dynamodb_table.ai_nexus_files.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach policy to S3 role
resource "aws_iam_role_policy_attachment" "ai_nexus_lambda_s3_policy_attachment" {
  role       = aws_iam_role.ai_nexus_lambda_s3_role.name
  policy_arn = aws_iam_policy.ai_nexus_lambda_s3_policy.arn
}

# Create placeholder Lambda function code
resource "local_file" "ai_nexus_user_data_lambda_code" {
  content = <<EOF
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const { httpMethod, pathParameters, body, requestContext } = event;
  const userId = requestContext.authorizer.claims.sub;
  
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    let response;
    
    switch (httpMethod) {
      case 'GET':
        response = await getUserData(userId, pathParameters);
        break;
      case 'POST':
        response = await createUserData(userId, JSON.parse(body));
        break;
      case 'PUT':
        response = await updateUserData(userId, JSON.parse(body));
        break;
      case 'DELETE':
        response = await deleteUserData(userId, pathParameters);
        break;
      default:
        response = {
          statusCode: 405,
          body: JSON.stringify({ error: 'Method not allowed' })
        };
    }
    
    return {
      ...response,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Content-Type': 'application/json'
      }
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};

async function getUserData(userId, pathParameters) {
  const params = {
    TableName: process.env.USER_DATA_TABLE_NAME,
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId
    }
  };
  
  if (pathParameters && pathParameters.dataType) {
    params.KeyConditionExpression += ' AND dataType = :dataType';
    params.ExpressionAttributeValues[':dataType'] = pathParameters.dataType;
  }
  
  const result = await dynamodb.query(params).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify(result.Items)
  };
}

async function createUserData(userId, data) {
  const item = {
    userId,
    dataType: data.dataType,
    ...data,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  
  const params = {
    TableName: process.env.USER_DATA_TABLE_NAME,
    Item: item
  };
  
  await dynamodb.put(params).promise();
  
  return {
    statusCode: 201,
    body: JSON.stringify(item)
  };
}

async function updateUserData(userId, data) {
  const params = {
    TableName: process.env.USER_DATA_TABLE_NAME,
    Key: {
      userId,
      dataType: data.dataType
    },
    UpdateExpression: 'SET #data = :data, updatedAt = :updatedAt',
    ExpressionAttributeNames: {
      '#data': 'data'
    },
    ExpressionAttributeValues: {
      ':data': data.data,
      ':updatedAt': new Date().toISOString()
    },
    ReturnValues: 'ALL_NEW'
  };
  
  const result = await dynamodb.update(params).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify(result.Attributes)
  };
}

async function deleteUserData(userId, pathParameters) {
  const params = {
    TableName: process.env.USER_DATA_TABLE_NAME,
    Key: {
      userId,
      dataType: pathParameters.dataType
    }
  };
  
  await dynamodb.delete(params).promise();
  
  return {
    statusCode: 204,
    body: ''
  };
}
EOF

  filename = "lambda/ai-nexus-user-data/index.js"
}

resource "local_file" "ai_nexus_files_lambda_code" {
  content = <<EOF
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const { httpMethod, pathParameters, body, requestContext } = event;
  const userId = requestContext.authorizer.claims.sub;
  
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    let response;
    
    switch (httpMethod) {
      case 'GET':
        if (pathParameters && pathParameters.action === 'presigned-url') {
          response = await generatePresignedUrl(userId, JSON.parse(body));
        } else {
          response = await getFilesList(userId);
        }
        break;
      case 'POST':
        response = await createFileRecord(userId, JSON.parse(body));
        break;
      case 'DELETE':
        response = await deleteFile(userId, pathParameters);
        break;
      default:
        response = {
          statusCode: 405,
          body: JSON.stringify({ error: 'Method not allowed' })
        };
    }
    
    return {
      ...response,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Content-Type': 'application/json'
      }
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};

async function generatePresignedUrl(userId, { fileName, fileType, operation = 'putObject' }) {
  const key = `private/${userId}/${fileName}`;
  
  const params = {
    Bucket: process.env.S3_BUCKET_NAME,
    Key: key,
    Expires: 3600, // 1 hour
    ContentType: fileType
  };
  
  const url = s3.getSignedUrl(operation, params);
  
  return {
    statusCode: 200,
    body: JSON.stringify({ 
      uploadUrl: url,
      key: key
    })
  };
}

async function createFileRecord(userId, fileData) {
  const fileId = require('crypto').randomUUID();
  
  const item = {
    fileId,
    version: 1,
    userId,
    fileName: fileData.fileName,
    fileSize: fileData.fileSize,
    fileType: fileData.fileType,
    s3Key: fileData.s3Key,
    uploadedAt: new Date().toISOString(),
    status: 'uploaded'
  };
  
  const params = {
    TableName: process.env.FILES_TABLE_NAME,
    Item: item
  };
  
  await dynamodb.put(params).promise();
  
  return {
    statusCode: 201,
    body: JSON.stringify(item)
  };
}

async function getFilesList(userId) {
  const params = {
    TableName: process.env.FILES_TABLE_NAME,
    IndexName: 'UserFilesIndex',
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId
    },
    ScanIndexForward: false // Most recent first
  };
  
  const result = await dynamodb.query(params).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify(result.Items)
  };
}

async function deleteFile(userId, pathParameters) {
  const { fileId } = pathParameters;
  
  // Get file record first
  const getParams = {
    TableName: process.env.FILES_TABLE_NAME,
    Key: {
      fileId,
      version: 1
    }
  };
  
  const fileRecord = await dynamodb.get(getParams).promise();
  
  if (!fileRecord.Item || fileRecord.Item.userId !== userId) {
    return {
      statusCode: 404,
      body: JSON.stringify({ error: 'File not found' })
    };
  }
  
  // Delete from S3
  const s3Params = {
    Bucket: process.env.S3_BUCKET_NAME,
    Key: fileRecord.Item.s3Key
  };
  
  await s3.deleteObject(s3Params).promise();
  
  // Delete record from DynamoDB
  await dynamodb.delete(getParams).promise();
  
  return {
    statusCode: 204,
    body: ''
  };
}
EOF

  filename = "lambda/ai-nexus-files/index.js"
}

resource "local_file" "ai_nexus_sessions_lambda_code" {
  content = <<EOF
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const { httpMethod, body, requestContext } = event;
  const userId = requestContext.authorizer.claims.sub;
  
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    let response;
    
    switch (httpMethod) {
      case 'POST':
        response = await createSession(userId, JSON.parse(body));
        break;
      case 'GET':
        response = await getUserSessions(userId);
        break;
      case 'PUT':
        response = await updateSession(userId, JSON.parse(body));
        break;
      default:
        response = {
          statusCode: 405,
          body: JSON.stringify({ error: 'Method not allowed' })
        };
    }
    
    return {
      ...response,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Content-Type': 'application/json'
      }
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};

async function createSession(userId, sessionData) {
  const sessionId = require('crypto').randomUUID();
  const now = new Date().toISOString();
  
  const item = {
    sessionId,
    userId,
    ...sessionData,
    createdAt: now,
    updatedAt: now,
    expiresAt: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60) // 30 days
  };
  
  const params = {
    TableName: process.env.SESSIONS_TABLE_NAME,
    Item: item
  };
  
  await dynamodb.put(params).promise();
  
  return {
    statusCode: 201,
    body: JSON.stringify(item)
  };
}

async function getUserSessions(userId) {
  const params = {
    TableName: process.env.SESSIONS_TABLE_NAME,
    IndexName: 'UserSessionsIndex',
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId
    },
    ScanIndexForward: false,
    Limit: 50
  };
  
  const result = await dynamodb.query(params).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify(result.Items)
  };
}

async function updateSession(userId, { sessionId, ...updateData }) {
  const params = {
    TableName: process.env.SESSIONS_TABLE_NAME,
    Key: { sessionId },
    UpdateExpression: 'SET updatedAt = :updatedAt',
    ExpressionAttributeValues: {
      ':updatedAt': new Date().toISOString(),
      ':userId': userId
    },
    ConditionExpression: 'userId = :userId',
    ReturnValues: 'ALL_NEW'
  };
  
  // Add dynamic update expressions for provided fields
  const updateExpressions = [];
  Object.keys(updateData).forEach(key => {
    updateExpressions.push(`${key} = :${key}`);
    params.ExpressionAttributeValues[`:${key}`] = updateData[key];
  });
  
  if (updateExpressions.length > 0) {
    params.UpdateExpression += ', ' + updateExpressions.join(', ');
  }
  
  const result = await dynamodb.update(params).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify(result.Attributes)
  };
}
EOF

  filename = "lambda/ai-nexus-sessions/index.js"
}

# Create ZIP files for Lambda functions
data "archive_file" "ai_nexus_user_data_lambda_zip" {
  type        = "zip"
  source_dir  = "lambda/ai-nexus-user-data"
  output_path = "lambda/ai-nexus-user-data.zip"
  depends_on  = [local_file.ai_nexus_user_data_lambda_code]
}

data "archive_file" "ai_nexus_files_lambda_zip" {
  type        = "zip"
  source_dir  = "lambda/ai-nexus-files"
  output_path = "lambda/ai-nexus-files.zip"
  depends_on  = [local_file.ai_nexus_files_lambda_code]
}

data "archive_file" "ai_nexus_sessions_lambda_zip" {
  type        = "zip"
  source_dir  = "lambda/ai-nexus-sessions"
  output_path = "lambda/ai-nexus-sessions.zip"
  depends_on  = [local_file.ai_nexus_sessions_lambda_code]
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "ai_nexus_user_data_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ai_nexus_user_data_lambda.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-user-data-lambda-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "ai_nexus_files_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ai_nexus_files_lambda.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-files-lambda-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "ai_nexus_sessions_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ai_nexus_sessions_lambda.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-sessions-lambda-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Outputs
output "ai_nexus_user_data_lambda_function_name" {
  description = "Name of the User Data Lambda function"
  value       = aws_lambda_function.ai_nexus_user_data_lambda.function_name
}

output "ai_nexus_files_lambda_function_name" {
  description = "Name of the Files Lambda function"
  value       = aws_lambda_function.ai_nexus_files_lambda.function_name
}

output "ai_nexus_sessions_lambda_function_name" {
  description = "Name of the Sessions Lambda function"
  value       = aws_lambda_function.ai_nexus_sessions_lambda.function_name
}
