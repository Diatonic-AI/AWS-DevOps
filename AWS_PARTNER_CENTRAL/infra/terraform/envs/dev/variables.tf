variable "env" {
  type        = string
  default     = "dev"
  description = "Environment name"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for deployment"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.60.0.0/16"
  description = "CIDR block for VPC"
}

variable "allow_destroy" {
  type        = bool
  default     = false
  description = "Allow destruction of stateful resources. Set via TF_VAR_allow_destroy=true"
}
