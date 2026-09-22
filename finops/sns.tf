data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "finops_alerts" {
  name = "cloudcontent-finops-alerts"

  tags = {
    Project   = "CloudContent"
    Purpose   = "FinOps"
    ManagedBy = "Terraform"
  }
}

data "aws_iam_policy_document" "finops_alerts" {
  statement {
    sid    = "AllowBudgetsPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    actions = [
      "SNS:Publish"
    ]

    resources = [
      aws_sns_topic.finops_alerts.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:budgets::${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }

  statement {
    sid    = "AllowCostAnomalyDetectionPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["costalerts.amazonaws.com"]
    }

    actions = [
      "SNS:Publish"
    ]

    resources = [
      aws_sns_topic.finops_alerts.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "finops_alerts" {
  arn    = aws_sns_topic.finops_alerts.arn
  policy = data.aws_iam_policy_document.finops_alerts.json
}

resource "aws_sns_topic_subscription" "finops_email" {
  topic_arn = aws_sns_topic.finops_alerts.arn
  protocol  = "email"
  endpoint  = var.finops_notification_email
}
