output "component_id" {
  description = "Identificador do recurso terraform_data deste componente."
  value       = terraform_data.component.id
}

output "component_summary" {
  description = "Dados registrados pelo recurso apos a aplicacao."
  value       = terraform_data.component.output
}
