variable "aws_region" {
  description = "AWS Region used by CloudContent governance FinOps resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "finops_notification_email" {
  description = "Email address that receives CloudContent FinOps alerts."
  type        = string
}
