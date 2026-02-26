# Marketplace Access Module
# IAM policies for AWS Marketplace Catalog + Metering API access

data "aws_iam_policy_document" "marketplace" {
  # Subscription management
  statement {
    sid    = "MarketplaceSubscriptions"
    effect = "Allow"
    actions = [
      "aws-marketplace:ViewSubscriptions",
      "aws-marketplace:Subscribe",
      "aws-marketplace:Unsubscribe"
    ]
    resources = ["*"]
  }

  # Catalog API (product/offer management)
  statement {
    sid    = "MarketplaceCatalog"
    effect = "Allow"
    actions = [
      "aws-marketplace:ListEntities",
      "aws-marketplace:DescribeEntity",
      "aws-marketplace:ListChangeSets",
      "aws-marketplace:DescribeChangeSet",
      "aws-marketplace:StartChangeSet",
      "aws-marketplace:CancelChangeSet",
      "aws-marketplace:GetResourcePolicy",
      "aws-marketplace:PutResourcePolicy",
      "aws-marketplace:DeleteResourcePolicy"
    ]
    resources = ["*"]
  }

  # Metering API (usage reporting)
  statement {
    sid    = "MarketplaceMetering"
    effect = "Allow"
    actions = [
      "aws-marketplace:MeterUsage",
      "aws-marketplace:BatchMeterUsage",
      "aws-marketplace:RegisterUsage"
    ]
    resources = ["*"]
  }

  # Entitlement API (SaaS access validation)
  statement {
    sid    = "MarketplaceEntitlements"
    effect = "Allow"
    actions = [
      "aws-marketplace:GetEntitlements"
    ]
    resources = ["*"]
  }

  # Agreement/offer management
  statement {
    sid    = "MarketplaceAgreements"
    effect = "Allow"
    actions = [
      "aws-marketplace:SearchAgreements",
      "aws-marketplace:DescribeAgreement",
      "aws-marketplace:GetAgreementTerms"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "marketplace_policy" {
  name        = "${var.name}-marketplace-policy"
  description = "IAM policy for AWS Marketplace Catalog and Metering API access"
  policy      = data.aws_iam_policy_document.marketplace.json

  tags = var.tags
}

# Optional: Create IAM role for Marketplace connector
resource "aws_iam_role" "marketplace_connector" {
  count = var.create_role ? 1 : 0

  name = "${var.name}-marketplace-connector"

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

resource "aws_iam_role_policy_attachment" "marketplace_connector" {
  count = var.create_role ? 1 : 0

  role       = aws_iam_role.marketplace_connector[0].name
  policy_arn = aws_iam_policy.marketplace_policy.arn
}
