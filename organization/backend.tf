terraform {
  backend "s3" {
    key          = "organization/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}
