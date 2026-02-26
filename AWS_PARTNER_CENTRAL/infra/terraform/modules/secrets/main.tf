# Secrets Module
# Secrets Manager baseline configuration

variable "name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type = map(string)
}

# Placeholder secret for Partner Central credentials
resource "aws_secretsmanager_secret" "partnercentral" {
  name       = "${var.name}/partnercentral/credentials"
  kms_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name}-partnercentral-credentials"
  })
}

# Placeholder secret for Marketplace credentials
resource "aws_secretsmanager_secret" "marketplace" {
  name       = "${var.name}/marketplace/credentials"
  kms_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name}-marketplace-credentials"
  })
}

# Database credentials secret
resource "aws_secretsmanager_secret" "database" {
  name       = "${var.name}/database/credentials"
  kms_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name}-database-credentials"
  })
}

output "partnercentral_secret_arn" {
  value = aws_secretsmanager_secret.partnercentral.arn
}

output "marketplace_secret_arn" {
  value = aws_secretsmanager_secret.marketplace.arn
}

output "database_secret_arn" {
  value = aws_secretsmanager_secret.database.arn
}
