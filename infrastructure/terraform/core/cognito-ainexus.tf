# AWS Cognito User Pool for AI Nexus Workbench
resource "aws_cognito_user_pool" "ai_nexus_user_pool" {
  name = "${var.project_name}-${var.environment}-ai-nexus-users"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # User attributes
  username_attributes = ["email"]
  
  # Account recovery setting
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Auto-verified attributes
  auto_verified_attributes = ["email"]

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Admin create user config
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # Schema
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable            = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable            = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Verification message template
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "AI Nexus Workbench - Verify your account"
    email_message        = "Welcome to AI Nexus Workbench! Your verification code is {####}"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-user-pool"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "ai_nexus_client" {
  name         = "${var.project_name}-${var.environment}-ai-nexus-client"
  user_pool_id = aws_cognito_user_pool.ai_nexus_user_pool.id

  generate_secret = false

  # Allowed OAuth flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  # Callback URLs for different environments
  callback_urls = [
    "http://localhost:8080",
    "http://localhost:3000",
    "https://${var.domain_name}",
    "https://www.${var.domain_name}"
  ]

  logout_urls = [
    "http://localhost:8080",
    "http://localhost:3000", 
    "https://${var.domain_name}",
    "https://www.${var.domain_name}"
  ]

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Token validity periods
  access_token_validity  = 60    # 1 hour
  id_token_validity      = 60    # 1 hour
  refresh_token_validity = 30    # 30 days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Read and write attributes
  read_attributes  = ["email", "name", "email_verified"]
  write_attributes = ["email", "name"]
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "ai_nexus_domain" {
  domain       = "${var.project_name}-${var.environment}-ai-nexus-${random_id.cognito_domain_suffix.hex}"
  user_pool_id = aws_cognito_user_pool.ai_nexus_user_pool.id
}

resource "random_id" "cognito_domain_suffix" {
  byte_length = 4
}

# Cognito Identity Pool
resource "aws_cognito_identity_pool" "ai_nexus_identity_pool" {
  identity_pool_name               = "${var.project_name}_${var.environment}_ai_nexus_identity_pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.ai_nexus_client.id
    provider_name           = aws_cognito_user_pool.ai_nexus_user_pool.endpoint
    server_side_token_check = false
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-identity-pool"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# IAM roles for authenticated and unauthenticated users
resource "aws_iam_role" "authenticated" {
  name = "${var.project_name}-${var.environment}-ai-nexus-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.ai_nexus_identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-authenticated-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role" "unauthenticated" {
  name = "${var.project_name}-${var.environment}-ai-nexus-unauthenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.ai_nexus_identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-unauthenticated-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policies for authenticated users - access to user's own data and application services
resource "aws_iam_policy" "authenticated_user_policy" {
  name        = "${var.project_name}-${var.environment}-ai-nexus-authenticated-policy"
  description = "Policy for authenticated AI Nexus users"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 access for file uploads (user-specific prefix)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.ai_nexus_uploads.arn}/private/$${cognito-identity.amazonaws.com:sub}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.ai_nexus_uploads.arn
        Condition = {
          StringLike = {
            "s3:prefix" = "private/$${cognito-identity.amazonaws.com:sub}/"
          }
        }
      },
      # DynamoDB access for user data
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
          aws_dynamodb_table.ai_nexus_user_data.arn,
          "${aws_dynamodb_table.ai_nexus_user_data.arn}/index/*"
        ]
        Condition = {
          "ForAllValues:StringEquals" = {
            "dynamodb:LeadingKeys" = ["$${cognito-identity.amazonaws.com:sub}"]
          }
        }
      },
      # API Gateway invoke permissions
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "${aws_api_gateway_rest_api.ai_nexus_api.execution_arn}/*/*"
      }
    ]
  })
}

# Attach policy to authenticated role
resource "aws_iam_role_policy_attachment" "authenticated_policy_attachment" {
  role       = aws_iam_role.authenticated.name
  policy_arn = aws_iam_policy.authenticated_user_policy.arn
}

# Minimal policy for unauthenticated users
resource "aws_iam_policy" "unauthenticated_user_policy" {
  name        = "${var.project_name}-${var.environment}-ai-nexus-unauthenticated-policy"
  description = "Minimal policy for unauthenticated users"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mobileanalytics:PutEvents",
          "cognito-sync:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "unauthenticated_policy_attachment" {
  role       = aws_iam_role.unauthenticated.name
  policy_arn = aws_iam_policy.unauthenticated_user_policy.arn
}

# Attach roles to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "ai_nexus_identity_pool_roles" {
  identity_pool_id = aws_cognito_identity_pool.ai_nexus_identity_pool.id

  roles = {
    authenticated   = aws_iam_role.authenticated.arn
    unauthenticated = aws_iam_role.unauthenticated.arn
  }
}

# Outputs for the frontend configuration
output "ai_nexus_cognito_user_pool_id" {
  description = "Cognito User Pool ID for AI Nexus"
  value       = aws_cognito_user_pool.ai_nexus_user_pool.id
}

output "ai_nexus_cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID for AI Nexus"
  value       = aws_cognito_user_pool_client.ai_nexus_client.id
}

output "ai_nexus_cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID for AI Nexus"
  value       = aws_cognito_identity_pool.ai_nexus_identity_pool.id
}

output "ai_nexus_cognito_user_pool_domain" {
  description = "Cognito User Pool Domain for AI Nexus"
  value       = aws_cognito_user_pool_domain.ai_nexus_domain.domain
}

output "ai_nexus_cognito_user_pool_endpoint" {
  description = "Cognito User Pool Endpoint for AI Nexus"
  value       = aws_cognito_user_pool.ai_nexus_user_pool.endpoint
}

output "ai_nexus_aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}
