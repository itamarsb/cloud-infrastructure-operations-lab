output "account_id" {
  description = "ID da conta AWS autenticada."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Regiao AWS utilizada pelo bootstrap."
  value       = var.aws_region
}

output "state_bucket_name" {
  description = "Nome do bucket exclusivo para o estado do Lab 21."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN do bucket exclusivo para o estado do Lab 21."
  value       = aws_s3_bucket.state.arn
}

output "state_key" {
  description = "Chave S3 do estado do exercicio no workspace default."
  value       = local.state_key
}

output "lock_key" {
  description = "Chave S3 utilizada pelo bloqueio nativo do backend."
  value       = "${local.state_key}.tflock"
}

output "backend_config" {
  description = "Parametros para configurar o backend S3 do exercicio."
  value = {
    bucket              = aws_s3_bucket.state.id
    key                 = local.state_key
    region              = var.aws_region
    profile             = var.aws_profile
    allowed_account_ids = [var.expected_account_id]
    encrypt             = true
    use_lockfile        = true
  }

  depends_on = [
    aws_s3_bucket_public_access_block.state,
    aws_s3_bucket_ownership_controls.state,
    aws_s3_bucket_versioning.state,
    aws_s3_bucket_server_side_encryption_configuration.state,
    aws_s3_bucket_policy.state
  ]
}
