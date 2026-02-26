# Orchestration Module
# Step Functions for workflow orchestration

variable "name" {
  type = string
}

variable "event_bus_arn" {
  type = string
}

variable "dlq_arn" {
  type = string
}

variable "tags" {
  type = map(string)
}

# IAM role for Step Functions
resource "aws_iam_role" "stepfunctions" {
  name = "${var.name}-stepfunctions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "stepfunctions" {
  name = "${var.name}-stepfunctions-policy"
  role = aws_iam_role.stepfunctions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "events:PutEvents",
          "sqs:SendMessage",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Example: Ingestion workflow state machine
resource "aws_sfn_state_machine" "ingestion" {
  name     = "${var.name}-ingestion-workflow"
  role_arn = aws_iam_role.stepfunctions.arn

  definition = jsonencode({
    Comment = "Partner Central data ingestion workflow"
    StartAt = "ExtractData"
    States = {
      ExtractData = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = "placeholder-extract-function"
          "Payload.$" = "$"
        }
        Next = "ValidateData"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "HandleError"
          }
        ]
      }
      ValidateData = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = "placeholder-validate-function"
          "Payload.$" = "$"
        }
        Next = "TransformData"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "HandleError"
          }
        ]
      }
      TransformData = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = "placeholder-transform-function"
          "Payload.$" = "$"
        }
        Next = "LoadData"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "HandleError"
          }
        ]
      }
      LoadData = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = "placeholder-load-function"
          "Payload.$" = "$"
        }
        End = true
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "HandleError"
          }
        ]
      }
      HandleError = {
        Type = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl = "placeholder-dlq-url"
          "MessageBody.$" = "$"
        }
        End = true
      }
    }
  })

  tags = var.tags
}

output "stepfunctions_role_arn" {
  value = aws_iam_role.stepfunctions.arn
}

output "ingestion_state_machine_arn" {
  value = aws_sfn_state_machine.ingestion.arn
}
