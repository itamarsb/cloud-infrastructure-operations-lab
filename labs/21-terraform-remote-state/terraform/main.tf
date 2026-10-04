resource "terraform_data" "lab21" {
  input = {
    project     = "cloud-infrastructure-operations-lab"
    lab         = "21"
    name        = "terraform-remote-state"
    environment = "lab"
    version     = "v1"
  }

  lifecycle {
    precondition {
      condition     = terraform.workspace == "default"
      error_message = "O exercicio do Lab 21 exige o workspace default."
    }
  }
}
