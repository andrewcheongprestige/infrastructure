provider "aws" {
  region = "ap-southeast-2"

  # Safety guard: refuse to run against any other AWS account.
  allowed_account_ids = ["421089614203"]

  default_tags {
    tags = {
      Project     = "hub1"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}
