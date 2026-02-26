# Core Infrastructure Module Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

# Internet Gateway
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "IDs of the data subnets"
  value       = aws_subnet.data[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "data_subnet_cidrs" {
  description = "CIDR blocks of the data subnets"
  value       = aws_subnet.data[*].cidr_block
}

# NAT Gateway Outputs
output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = var.enable_nat_instance ? [] : aws_nat_gateway.main[*].id
}

output "nat_instance_id" {
  description = "ID of the NAT instance (if enabled)"
  value       = var.enable_nat_instance ? aws_instance.nat_instance[0].id : null
}

output "elastic_ips" {
  description = "Elastic IPs associated with NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

# Route Table Outputs
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

# Security Group Outputs
output "default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_default_security_group.default.id
}

output "web_security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "internal_security_group_id" {
  description = "ID of the internal security group"
  value       = aws_security_group.internal.id
}

# S3 Outputs
output "static_assets_bucket_id" {
  description = "ID of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.id
}

output "static_assets_bucket_arn" {
  description = "ARN of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.arn
}

output "static_assets_bucket_domain_name" {
  description = "Domain name of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket_domain_name
}

# Availability Zones
output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

# Flow Logs
output "flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = var.enable_flow_logs ? aws_flow_log.vpc[0].id : null
}

output "flow_log_group_name" {
  description = "Name of the Flow Logs CloudWatch Log Group"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_log[0].name : null
}

# Resource Name Prefix
output "name_prefix" {
  description = "Resource name prefix used by this module"
  value       = var.name_prefix
}

# Data for other modules
output "module_outputs" {
  description = "All outputs in a single object for easy reference"
  value = {
    vpc = {
      id         = aws_vpc.main.id
      cidr_block = aws_vpc.main.cidr_block
      arn        = aws_vpc.main.arn
    }
    subnets = {
      public  = aws_subnet.public[*].id
      private = aws_subnet.private[*].id
      data    = aws_subnet.data[*].id
    }
    security_groups = {
      default  = aws_default_security_group.default.id
      web      = aws_security_group.web.id
      internal = aws_security_group.internal.id
    }
    s3 = {
      static_assets = {
        id          = aws_s3_bucket.static_assets.id
        arn         = aws_s3_bucket.static_assets.arn
        domain_name = aws_s3_bucket.static_assets.bucket_domain_name
      }
    }
    networking = {
      internet_gateway_id     = aws_internet_gateway.main.id
      nat_gateway_ids         = var.enable_nat_instance ? [] : aws_nat_gateway.main[*].id
      nat_instance_id         = var.enable_nat_instance ? aws_instance.nat_instance[0].id : null
      public_route_table_id   = aws_route_table.public.id
      private_route_table_ids = aws_route_table.private[*].id
    }
  }
}
