provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project     = "cloud-infrastructure-operations-lab"
      Environment = "lab"
      Lab         = "20"
      ManagedBy   = "terraform"
      Owner       = "itamarsb"
    }
  }
}
