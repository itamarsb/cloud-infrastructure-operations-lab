resource "terraform_data" "component" {
  input = {
    project_name       = var.project_name
    environment        = var.environment
    component_name     = var.component_name
    replica_count      = var.replica_count
    monitoring_enabled = var.monitoring_enabled

    tags = merge(var.tags, {
      Project     = var.project_name
      Environment = var.environment
      Component   = var.component_name
      ManagedBy   = "terraform"
      Lab         = "22"
    })
  }
}
