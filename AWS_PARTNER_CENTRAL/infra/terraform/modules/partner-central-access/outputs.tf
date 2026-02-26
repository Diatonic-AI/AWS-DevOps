output "policy_arn" {
  description = "Partner Central IAM policy ARN"
  value       = aws_iam_policy.partnercentral_policy.arn
}

output "policy_name" {
  description = "Partner Central IAM policy name"
  value       = aws_iam_policy.partnercentral_policy.name
}

output "role_arn" {
  description = "Partner Central connector role ARN (if created)"
  value       = var.create_role ? aws_iam_role.partnercentral_connector[0].arn : null
}

output "role_name" {
  description = "Partner Central connector role name (if created)"
  value       = var.create_role ? aws_iam_role.partnercentral_connector[0].name : null
}
