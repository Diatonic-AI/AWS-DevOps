# Data Lake Module
# S3 bucket for lakehouse architecture

variable "name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type = map(string)
}

resource "aws_s3_bucket" "lake" {
  bucket = "${var.name}-lake"

  tags = merge(var.tags, {
    Name = "${var.name}-lake"
  })
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket = aws_s3_bucket.lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    id     = "bronze-lifecycle"
    status = "Enabled"

    filter {
      prefix = "bronze/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

# Create folder structure
resource "aws_s3_object" "bronze_prefix" {
  bucket = aws_s3_bucket.lake.id
  key    = "bronze/.keep"
  source = "/dev/null"
}

resource "aws_s3_object" "silver_prefix" {
  bucket = aws_s3_bucket.lake.id
  key    = "silver/.keep"
  source = "/dev/null"
}

resource "aws_s3_object" "gold_prefix" {
  bucket = aws_s3_bucket.lake.id
  key    = "gold/.keep"
  source = "/dev/null"
}

resource "aws_s3_object" "platinum_prefix" {
  bucket = aws_s3_bucket.lake.id
  key    = "platinum/.keep"
  source = "/dev/null"
}

output "bucket_name" {
  value = aws_s3_bucket.lake.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.lake.arn
}
