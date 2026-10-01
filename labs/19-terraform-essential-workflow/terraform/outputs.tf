output "resource_id" {
  description = "Identificador do recurso local gerenciado pelo Terraform."
  value       = terraform_data.lab19.id
}

output "lab_summary" {
  description = "Dados do laboratorio registrados no recurso local."
  value       = terraform_data.lab19.output
}
