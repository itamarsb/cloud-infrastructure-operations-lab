terraform {
  required_version = ">= 1.16.1, < 1.17.0"

  backend "local" {
    path = "terraform.tfstate"
  }
}
