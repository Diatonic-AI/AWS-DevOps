output "amplify_app" { value = data.aws_amplify_app.web }
output "cognito_user_pool" { value = data.aws_cognito_user_pool.main.id }
output "api_gateway" { value = try(data.aws_apigatewayv2_api.api_http[0].api_endpoint, null) }
output "stripe_secrets" { value = { secret = data.aws_secretsmanager_secret.stripe_secret.arn webhook = data.aws_secretsmanager_secret.stripe_webhook_secret.arn } }
