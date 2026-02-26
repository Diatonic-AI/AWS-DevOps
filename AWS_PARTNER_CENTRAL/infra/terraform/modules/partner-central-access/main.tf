# Partner Central Access Module
# IAM policies for AWS Partner Central API access

data "aws_iam_policy_document" "partnercentral" {
  # Read operations
  statement {
    sid    = "PartnerCentralRead"
    effect = "Allow"
    actions = [
      "partnercentral-selling:GetOpportunity",
      "partnercentral-selling:ListOpportunities",
      "partnercentral-selling:GetEngagementInvitation",
      "partnercentral-selling:ListEngagementInvitations",
      "partnercentral-selling:GetResourceSnapshot",
      "partnercentral-selling:ListResourceSnapshots",
      "partnercentral-selling:ListSolutions"
    ]
    resources = ["*"]
  }

  # Write operations (approval-gated at application level)
  statement {
    sid    = "PartnerCentralWrite"
    effect = "Allow"
    actions = [
      "partnercentral-selling:CreateOpportunity",
      "partnercentral-selling:UpdateOpportunity",
      "partnercentral-selling:AssociateOpportunity",
      "partnercentral-selling:DisassociateOpportunity",
      "partnercentral-selling:StartEngagementFromOpportunity",
      "partnercentral-selling:StartEngagementByAcceptingInvitationTask",
      "partnercentral-selling:SubmitOpportunity",
      "partnercentral-selling:CreateResourceSnapshot",
      "partnercentral-selling:CreateResourceSnapshotJob"
    ]
    resources = ["*"]
  }

  # Task management
  statement {
    sid    = "PartnerCentralTasks"
    effect = "Allow"
    actions = [
      "partnercentral-selling:GetEngagementInvitation",
      "partnercentral-selling:ListEngagementInvitations",
      "partnercentral-selling:AcceptEngagementInvitation",
      "partnercentral-selling:RejectEngagementInvitation"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "partnercentral_policy" {
  name        = "${var.name}-partnercentral-policy"
  description = "IAM policy for AWS Partner Central API access"
  policy      = data.aws_iam_policy_document.partnercentral.json

  tags = var.tags
}

# Optional: Create IAM role for Partner Central connector
resource "aws_iam_role" "partnercentral_connector" {
  count = var.create_role ? 1 : 0

  name = "${var.name}-partnercentral-connector"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "partnercentral_connector" {
  count = var.create_role ? 1 : 0

  role       = aws_iam_role.partnercentral_connector[0].name
  policy_arn = aws_iam_policy.partnercentral_policy.arn
}
