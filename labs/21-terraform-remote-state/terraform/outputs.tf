output "resource_id" {
  description = "Identificador do recurso utilizado no exercicio de estado remoto."
  value       = terraform_data.lab21.id
}

output "lab_summary" {
  description = "Dados do laboratorio preservados durante a migracao do estado."
  value       = terraform_data.lab21.output
}
