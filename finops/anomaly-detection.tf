resource "aws_ce_anomaly_monitor" "aws_services" {
  name              = "Default-Services-Monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = {
    Project   = "CloudContent"
    Purpose   = "FinOps"
    ManagedBy = "Terraform"
  }
}

resource "aws_ce_anomaly_subscription" "immediate_alerts" {
  name      = "cloudcontent-immediate-cost-anomalies"
  frequency = "IMMEDIATE"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.aws_services.arn
  ]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.finops_alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["1"]
    }
  }

  tags = {
    Project   = "CloudContent"
    Purpose   = "FinOps"
    ManagedBy = "Terraform"
  }

  depends_on = [
    aws_sns_topic_policy.finops_alerts
  ]
}
