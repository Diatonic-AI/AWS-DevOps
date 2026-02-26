# Analytics Warehouse Module
# Redshift Serverless for analytics

variable "name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type = map(string)
}

resource "aws_security_group" "redshift" {
  name_prefix = "${var.name}-redshift-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Redshift from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-redshift-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_redshiftserverless_namespace" "this" {
  namespace_name      = "${var.name}-analytics"
  admin_username      = "admin"
  manage_admin_password = true
  db_name             = "analytics"
  kms_key_id          = var.kms_key_arn

  tags = var.tags
}

resource "aws_redshiftserverless_workgroup" "this" {
  namespace_name = aws_redshiftserverless_namespace.this.namespace_name
  workgroup_name = "${var.name}-workgroup"
  base_capacity  = 8  # 8 RPU minimum

  security_group_ids = [aws_security_group.redshift.id]
  subnet_ids         = var.subnet_ids

  config_parameter {
    parameter_key   = "auto_mv"
    parameter_value = "true"
  }

  config_parameter {
    parameter_key   = "datestyle"
    parameter_value = "ISO, MDY"
  }

  tags = var.tags
}

output "workgroup_name" {
  value = aws_redshiftserverless_workgroup.this.workgroup_name
}

output "namespace_name" {
  value = aws_redshiftserverless_namespace.this.namespace_name
}

output "endpoint" {
  value = aws_redshiftserverless_workgroup.this.endpoint
}
