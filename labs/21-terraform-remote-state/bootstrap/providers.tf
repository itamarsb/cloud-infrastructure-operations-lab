provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project     = "cloud-infrastructure-operations-lab"
      Environment = "lab"
      Lab         = "21"
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}
