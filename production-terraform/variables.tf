variable "aws_region" { type = string default = "us-east-2" }
variable "domain_name" { type = string description = "Primary apex domain" }
variable "hosted_zone_id" { type = string description = "Route53 hosted zone ID" }
variable "amplify_app_id" { type = string description = "Existing Amplify App ID to import/manage" }
variable "api_gateway_id" { type = string description = "Existing API Gateway (HTTP or REST) ID" }
variable "cognito_user_pool_id" { type = string description = "Existing Cognito User Pool ID" }
variable "cognito_identity_pool_id" { type = string description = "Existing Cognito Identity Pool ID" }
variable "stripe_secret_arn" { type = string description = "Secrets Manager ARN for Stripe secret key" }
variable "stripe_webhook_secret_arn" { type = string description = "Secrets Manager ARN for Stripe webhook signing secret" }
