terraform {
  required_version = ">= 1.4.0, < 2.0.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "= 2.9.1"
    }
  }
}
