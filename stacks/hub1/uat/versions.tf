terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Its own state, separate from the other stacks', so a mistake in one cannot touch another.
  backend "s3" {
    bucket       = "prestige-terraform-state-421089614203"
    key          = "hub1/uat/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
