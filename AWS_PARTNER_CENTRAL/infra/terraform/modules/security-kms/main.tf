# KMS Keys Module
# Creates CMKs for encryption across the platform

# KMS key for Secrets Manager
resource "aws_kms_key" "secrets" {
  description             = "${var.name} - Secrets Manager encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name}-secrets-key"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# KMS key for Data Lake (S3)
resource "aws_kms_key" "lake" {
  description             = "${var.name} - Data Lake encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name}-lake-key"
  })
}

resource "aws_kms_alias" "lake" {
  name          = "alias/${var.name}-lake"
  target_key_id = aws_kms_key.lake.key_id
}

# KMS key for Database
resource "aws_kms_key" "db" {
  description             = "${var.name} - Database encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name}-db-key"
  })
}

resource "aws_kms_alias" "db" {
  name          = "alias/${var.name}-db"
  target_key_id = aws_kms_key.db.key_id
}

# KMS key for Analytics Warehouse
resource "aws_kms_key" "warehouse" {
  description             = "${var.name} - Warehouse encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name}-warehouse-key"
  })
}

resource "aws_kms_alias" "warehouse" {
  name          = "alias/${var.name}-warehouse"
  target_key_id = aws_kms_key.warehouse.key_id
}
