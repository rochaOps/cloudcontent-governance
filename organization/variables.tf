variable "sandbox_account_email" {
  description = "Email address used by the AWS Organizations sandbox member account."
  type        = string
  #  sensitive   = true
}

variable "identity_center_admin_username" {
  description = "IAM Identity Center username assigned AdministratorAccess to the sandbox account."
  type        = string
  #  sensitive   = true
}
