output "managed_file_path" {
  description = "Caminho absoluto do arquivo gerenciado pelo laboratorio."
  value       = local_file.application_config.filename
}

output "expected_content_sha256" {
  description = "SHA256 do conteudo declarado, incluindo a quebra de linha final."
  value       = sha256(local.application_config_content)
}

output "recorded_configuration" {
  description = "Configuracao registrada no recurso Terraform; nao substitui a leitura direta do arquivo."
  value       = jsondecode(local_file.application_config.content)
}
