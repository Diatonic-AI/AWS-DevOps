variable "name" {
  type        = string
  description = "Name prefix for resources"
}

variable "cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}
