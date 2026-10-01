resource "terraform_data" "lab19" {
  input = {
    project     = "cloud-infrastructure-operations-lab"
    lab         = "19"
    name        = "terraform-essential-workflow"
    environment = "local"
    version     = "v1"
  }
}
