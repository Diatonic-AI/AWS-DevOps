# ECR Repository for AI Nexus Workbench Application
# This file creates the container registry for the ai-nexus-workbench application

# ECR Repository
resource "aws_ecr_repository" "ai_nexus_workbench" {
  name                 = "ai-nexus-workbench"
  image_tag_mutability = "IMMUTABLE" # Recommended for production security

  image_scanning_configuration {
    scan_on_push = true # Security scanning enabled
  }

  encryption_configuration {
    encryption_type = "AES256" # Default AWS managed encryption (no additional cost)
  }

  tags = merge(local.common_tags, {
    Component    = "container-registry"
    Application  = "ai-nexus-workbench"
    Tier         = "infrastructure"
    CostCategory = "application"
  })
}

# Lifecycle policy to manage image retention and costs
resource "aws_ecr_lifecycle_policy" "ai_nexus_workbench" {
  repository = aws_ecr_repository.ai_nexus_workbench.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the latest 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the latest 5 development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "feature", "main"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository policy for cross-account access if needed
resource "aws_ecr_repository_policy" "ai_nexus_workbench" {
  repository = aws_ecr_repository.ai_nexus_workbench.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanResults",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
      }
    ]
  })
}

# Note: aws_caller_identity data source is defined in backend.tf

# Outputs for the ECR repository
output "ai_nexus_workbench_ecr_repository_url" {
  description = "The URL of the ECR repository for ai-nexus-workbench"
  value       = aws_ecr_repository.ai_nexus_workbench.repository_url
}

output "ai_nexus_workbench_ecr_repository_arn" {
  description = "The ARN of the ECR repository for ai-nexus-workbench"
  value       = aws_ecr_repository.ai_nexus_workbench.arn
}

output "ai_nexus_workbench_ecr_repository_name" {
  description = "The name of the ECR repository for ai-nexus-workbench"
  value       = aws_ecr_repository.ai_nexus_workbench.name
}
