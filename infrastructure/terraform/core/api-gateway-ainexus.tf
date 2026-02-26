# API Gateway for AI Nexus backend services
resource "aws_api_gateway_rest_api" "ai_nexus_api" {
  name        = "${var.project_name}-${var.environment}-ai-nexus-api"
  description = "API Gateway for AI Nexus Workbench backend services"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-api"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "ai_nexus_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.ai_nexus_user_data_integration,
    aws_api_gateway_integration.ai_nexus_files_integration,
    aws_api_gateway_integration.ai_nexus_sessions_integration,
    aws_api_gateway_method.options_method
  ]

  rest_api_id = aws_api_gateway_rest_api.ai_nexus_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.ai_nexus_user_data_resource.id,
      aws_api_gateway_method.ai_nexus_user_data_method.id,
      aws_api_gateway_integration.ai_nexus_user_data_integration.id,
      aws_api_gateway_resource.ai_nexus_files_resource.id,
      aws_api_gateway_method.ai_nexus_files_method.id,
      aws_api_gateway_integration.ai_nexus_files_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "ai_nexus_api_stage" {
  deployment_id = aws_api_gateway_deployment.ai_nexus_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.ai_nexus_api.id
  stage_name    = var.environment

  # Enable CloudWatch logging
  xray_tracing_config {
    tracing_mode = "Active"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-api-stage"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "ai_nexus_api_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.ai_nexus_api.name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-api-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway Authorizer using Cognito User Pool
resource "aws_api_gateway_authorizer" "ai_nexus_cognito_authorizer" {
  name          = "${var.project_name}-${var.environment}-ai-nexus-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.ai_nexus_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.ai_nexus_user_pool.arn]
}

# CORS OPTIONS method for all resources
resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id   = aws_api_gateway_rest_api.ai_nexus_api.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id = aws_api_gateway_rest_api.ai_nexus_api.root_resource_id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id = aws_api_gateway_rest_api.ai_nexus_api.root_resource_id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id = aws_api_gateway_rest_api.ai_nexus_api.root_resource_id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
  }
}

# User Data Resource
resource "aws_api_gateway_resource" "ai_nexus_user_data_resource" {
  rest_api_id = aws_api_gateway_rest_api.ai_nexus_api.id
  parent_id   = aws_api_gateway_rest_api.ai_nexus_api.root_resource_id
  path_part   = "user-data"
}

# User Data Methods
resource "aws_api_gateway_method" "ai_nexus_user_data_method" {
  rest_api_id   = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id   = aws_api_gateway_resource.ai_nexus_user_data_resource.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.ai_nexus_cognito_authorizer.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# User Data Lambda Integration
resource "aws_api_gateway_integration" "ai_nexus_user_data_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id             = aws_api_gateway_resource.ai_nexus_user_data_resource.id
  http_method             = aws_api_gateway_method.ai_nexus_user_data_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ai_nexus_user_data_lambda.invoke_arn
}

# Files Resource
resource "aws_api_gateway_resource" "ai_nexus_files_resource" {
  rest_api_id = aws_api_gateway_rest_api.ai_nexus_api.id
  parent_id   = aws_api_gateway_rest_api.ai_nexus_api.root_resource_id
  path_part   = "files"
}

# Files Methods
resource "aws_api_gateway_method" "ai_nexus_files_method" {
  rest_api_id   = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id   = aws_api_gateway_resource.ai_nexus_files_resource.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.ai_nexus_cognito_authorizer.id
}

# Files Lambda Integration
resource "aws_api_gateway_integration" "ai_nexus_files_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id             = aws_api_gateway_resource.ai_nexus_files_resource.id
  http_method             = aws_api_gateway_method.ai_nexus_files_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ai_nexus_files_lambda.invoke_arn
}

# Sessions Resource
resource "aws_api_gateway_resource" "ai_nexus_sessions_resource" {
  rest_api_id = aws_api_gateway_rest_api.ai_nexus_api.id
  parent_id   = aws_api_gateway_rest_api.ai_nexus_api.root_resource_id
  path_part   = "sessions"
}

# Sessions Methods
resource "aws_api_gateway_method" "ai_nexus_sessions_method" {
  rest_api_id   = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id   = aws_api_gateway_resource.ai_nexus_sessions_resource.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.ai_nexus_cognito_authorizer.id
}

# Sessions Lambda Integration
resource "aws_api_gateway_integration" "ai_nexus_sessions_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ai_nexus_api.id
  resource_id             = aws_api_gateway_resource.ai_nexus_sessions_resource.id
  http_method             = aws_api_gateway_method.ai_nexus_sessions_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ai_nexus_sessions_lambda.invoke_arn
}

# Lambda permission for API Gateway to invoke functions
resource "aws_lambda_permission" "ai_nexus_api_lambda_user_data" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_nexus_user_data_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ai_nexus_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "ai_nexus_api_lambda_files" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_nexus_files_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ai_nexus_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "ai_nexus_api_lambda_sessions" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_nexus_sessions_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ai_nexus_api.execution_arn}/*/*"
}

# API Gateway Custom Domain (optional)
resource "aws_api_gateway_domain_name" "ai_nexus_api_domain" {
  count       = var.create_custom_domain ? 1 : 0
  domain_name = "api.${var.domain_name}"

  certificate_arn = var.ssl_certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-api-domain"
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "ai_nexus_api_mapping" {
  count       = var.create_custom_domain ? 1 : 0
  api_id      = aws_api_gateway_rest_api.ai_nexus_api.id
  stage_name  = aws_api_gateway_stage.ai_nexus_api_stage.stage_name
  domain_name = aws_api_gateway_domain_name.ai_nexus_api_domain[0].domain_name
}

# Route53 record for custom domain
resource "aws_route53_record" "ai_nexus_api_domain_record" {
  count   = var.create_custom_domain ? 1 : 0
  zone_id = var.route53_zone_id
  name    = aws_api_gateway_domain_name.ai_nexus_api_domain[0].domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.ai_nexus_api_domain[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.ai_nexus_api_domain[0].cloudfront_zone_id
    evaluate_target_health = true
  }
}

# Outputs
output "ai_nexus_api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.ai_nexus_api.id
}

output "ai_nexus_api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.ai_nexus_api.execution_arn
}

output "ai_nexus_api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.ai_nexus_api_stage.invoke_url
}

output "ai_nexus_api_gateway_custom_domain_name" {
  description = "Custom domain name for the API Gateway"
  value       = var.create_custom_domain ? aws_api_gateway_domain_name.ai_nexus_api_domain[0].domain_name : null
}
