locals {
  application_config_path = abspath(
    "${path.module}/../local-artifacts/application-config.json"
  )

  application_config = {
    project_name        = var.project_name
    environment         = var.environment
    application_version = var.application_version
    log_level           = var.log_level
    managed_by          = "terraform"
    lab                 = "23"
  }

  application_config_content = "${jsonencode(local.application_config)}\n"
}

resource "local_file" "application_config" {
  filename = local.application_config_path
  content  = local.application_config_content
}
