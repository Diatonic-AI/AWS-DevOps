output "policy_arn" {
  description = "Marketplace IAM policy ARN"
  value       = aws_iam_policy.marketplace_policy.arn
}

output "policy_name" {
  description = "Marketplace IAM policy name"
  value       = aws_iam_policy.marketplace_policy.name
}

output "role_arn" {
  description = "Marketplace connector role ARN (if created)"
  value       = var.create_role ? aws_iam_role.marketplace_connector[0].arn : null
}

output "role_name" {
  description = "Marketplace connector role name (if created)"
  value       = var.create_role ? aws_iam_role.marketplace_connector[0].name : null
}
