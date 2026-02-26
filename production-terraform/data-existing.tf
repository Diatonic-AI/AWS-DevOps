# Data sources referencing existing production resources (to avoid recreation)

data "aws_cognito_user_pool" "main" { id = var.cognito_user_pool_id }
# Identity pool (no native data source; can use aws_cognito_identity_pool if created via TF in future)

data "aws_secretsmanager_secret" "stripe_secret" { arn = var.stripe_secret_arn }
data "aws_secretsmanager_secret" "stripe_webhook_secret" { arn = var.stripe_webhook_secret_arn }

data "aws_apigatewayv2_api" "api_http" { count = length(var.api_gateway_id) == 0 ? 0 : 1 api_id = var.api_gateway_id }

data "aws_amplify_app" "web" { app_id = var.amplify_app_id }
