terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State is stored per stack and environment to limit the blast radius of a mistake.
  backend "s3" {
    bucket       = "prestige-terraform-state-421089614203"
    key          = "client-portal/uat/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
