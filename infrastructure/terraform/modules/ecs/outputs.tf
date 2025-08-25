# ECS Module Outputs

# Load Balancer Information
output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Hosted Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

# ECS Information
output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

# Security Groups
output "alb_security_group_id" {
  description = "ID of the Application Load Balancer security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

# IAM Roles
output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution_role.arn
}

# Logging
output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.enable_logging ? aws_cloudwatch_log_group.main[0].name : null
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = var.enable_logging ? aws_cloudwatch_log_group.main[0].arn : null
}

# Application URL
output "application_url" {
  description = "URL to access the application"
  value       = var.enable_https ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

# Auto Scaling
output "autoscaling_target_resource_id" {
  description = "Resource ID of the auto scaling target"
  value       = var.enable_auto_scaling ? aws_appautoscaling_target.ecs_target[0].resource_id : null
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    fargate_cpu_memory = "~$15-35/month per task"
    load_balancer      = "~$16-20/month"
    cloudwatch_logs    = "~$1-3/month"
    total_estimate     = "~$32-58/month for ${var.desired_capacity} task(s)"
    task_configuration = "${var.container_cpu} CPU / ${var.container_memory} MB memory"
    capacity_provider  = var.environment == "production" ? "FARGATE" : "FARGATE_SPOT"
    auto_scaling       = var.enable_auto_scaling ? "Enabled (${var.min_capacity}-${var.max_capacity} tasks)" : "Disabled"
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of ECS configuration"
  value = {
    cluster_name         = aws_ecs_cluster.main.name
    service_name         = aws_ecs_service.main.name
    task_cpu             = var.container_cpu
    task_memory          = var.container_memory
    desired_count        = var.desired_capacity
    auto_scaling_enabled = var.enable_auto_scaling
    https_enabled        = var.enable_https
    logging_enabled      = var.enable_logging
    capacity_provider    = var.environment == "production" ? "FARGATE" : "FARGATE_SPOT"
    container_image      = var.container_image
    health_check_path    = var.health_check_path
  }
}
