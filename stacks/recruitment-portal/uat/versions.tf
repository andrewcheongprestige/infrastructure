terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Its own state, separate from the client portal's, so a mistake in one cannot touch the other.
  backend "s3" {
    bucket       = "prestige-terraform-state-421089614203"
    key          = "recruitment-portal/uat/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
