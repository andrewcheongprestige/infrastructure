provider "aws" {
  region = "ap-southeast-2"

  # Safety guard: refuse to run against any other AWS account.
  allowed_account_ids = ["421089614203"]

  default_tags {
    tags = {
      Project     = "admin-hub"
      Environment = "uat"
      ManagedBy   = "terraform"
    }
  }
}
