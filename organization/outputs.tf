output "organization_root_id" {
  value = data.aws_organizations_organization.current.roots[0].id
}