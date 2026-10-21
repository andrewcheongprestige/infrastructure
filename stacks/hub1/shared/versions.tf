terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Its own state, separate from the UAT stack's (and, later, Production's). The resources in this stack are
  # used by both the UAT and Production environments, so they are owned here once.
  backend "s3" {
    bucket       = "prestige-terraform-state-421089614203"
    key          = "hub1/shared/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
