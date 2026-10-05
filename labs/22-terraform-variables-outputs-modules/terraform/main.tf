module "application" {
  source = "./modules/lab-component"

  project_name       = var.project_name
  environment        = var.environment
  component_name     = "application"
  replica_count      = var.replica_count
  monitoring_enabled = var.monitoring_enabled
  tags               = var.common_tags
}

module "worker" {
  source = "./modules/lab-component"

  project_name       = var.project_name
  environment        = var.environment
  component_name     = "worker"
  replica_count      = 1
  monitoring_enabled = var.monitoring_enabled
  tags               = var.common_tags
}
