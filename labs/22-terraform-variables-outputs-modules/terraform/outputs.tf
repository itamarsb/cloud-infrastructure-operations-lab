output "component_ids" {
  description = "Identificadores dos dois recursos terraform_data."
  value = {
    application = module.application.component_id
    worker      = module.worker.component_id
  }
}

output "lab_summary" {
  description = "Dados dos componentes retornados pelo modulo filho."
  value = {
    application = module.application.component_summary
    worker      = module.worker.component_summary
  }
}
