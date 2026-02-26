variable "name" {
  type        = string
  description = "Name prefix for resources"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}

variable "create_role" {
  type        = bool
  default     = false
  description = "Whether to create an IAM role for the connector"
}
