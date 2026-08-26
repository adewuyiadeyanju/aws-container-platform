terraform {
  backend "s3" {
    bucket       = "aws-container-platform-dev-tfstate-506813471880"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}