resource "aws_organizations_organization" "current" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY"
  ]

  aws_service_access_principals = [
    "sso.amazonaws.com"
  ]
}