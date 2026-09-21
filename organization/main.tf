data "aws_organizations_organization" "current" {}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

resource "aws_organizations_account" "cloudcontent_sandbox" {
  name      = "cloudcontent-sandbox"
  email     = var.sandbox_account_email
  parent_id = aws_organizations_organizational_unit.sandbox.id

  close_on_deletion = false

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_ssoadmin_instances" "current" {}

data "aws_ssoadmin_permission_set" "administrator" {
  instance_arn = tolist(data.aws_ssoadmin_instances.current.arns)[0]
  name         = "AdministratorAccess"
}

data "aws_identitystore_user" "luis" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.current.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.identity_center_admin_username
    }
  }
}

resource "aws_ssoadmin_account_assignment" "luis_cloudcontent_admin" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.current.arns)[0]
  permission_set_arn = data.aws_ssoadmin_permission_set.administrator.arn

  principal_id   = data.aws_identitystore_user.luis.user_id
  principal_type = "USER"

  target_id   = aws_organizations_account.cloudcontent_sandbox.id
  target_type = "AWS_ACCOUNT"
}
