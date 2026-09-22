terraform {
  backend "s3" {
    bucket       = ""
    key          = "finops/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
    encrypt      = true
  }
}
