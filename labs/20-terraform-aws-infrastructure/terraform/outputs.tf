output "account_id" {
  description = "Conta AWS utilizada no provisionamento."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Regiao AWS utilizada pelo laboratorio."
  value       = var.aws_region
}

output "shared_vpc_id" {
  description = "VPC compartilhada do LAB 08."
  value       = data.aws_vpc.shared.id
}

output "shared_subnet_id" {
  description = "Sub-rede compartilhada do LAB 08."
  value       = data.aws_subnet.shared.id
}

output "ami_id" {
  description = "AMI utilizada pela instancia EC2."
  value       = aws_instance.application.ami
}

output "instance_id" {
  description = "Identificador da instancia EC2 do LAB 20."
  value       = aws_instance.application.id
}

output "instance_public_ip" {
  description = "IPv4 publico da instancia EC2."
  value       = aws_instance.application.public_ip
}

output "root_volume_id" {
  description = "Identificador do volume root da instancia."
  value       = aws_instance.application.root_block_device[0].volume_id
}

output "security_group_id" {
  description = "Security Group exclusivo do LAB 20."
  value       = aws_security_group.application.id
}

output "iam_role_name" {
  description = "IAM Role utilizada pela instancia."
  value       = aws_iam_role.ec2.name
}

output "instance_profile_name" {
  description = "Instance Profile associado a instancia."
  value       = aws_iam_instance_profile.ec2.name
}

output "allowed_http_cidr" {
  description = "IPv4 autorizado para acesso HTTP."
  value       = var.allowed_http_cidr
}

output "application_url" {
  description = "URL da pagina principal da aplicacao."
  value       = "http://${aws_instance.application.public_ip}/"
}

output "health_url" {
  description = "URL do endpoint de saude."
  value       = "http://${aws_instance.application.public_ip}/health"
}

output "version_url" {
  description = "URL do endpoint de versao."
  value       = "http://${aws_instance.application.public_ip}/version"
}
