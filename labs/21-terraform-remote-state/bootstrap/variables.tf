variable "aws_profile" {
  description = "Perfil AWS CLI utilizado para autenticacao temporaria."
  type        = string
  default     = "cloud-operations-lab"
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.aws_profile)) > 0 &&
      var.aws_profile == trimspace(var.aws_profile)
    )
    error_message = "Informe um perfil AWS nao vazio e sem espacos nas extremidades."
  }
}

variable "aws_region" {
  description = "Regiao AWS autorizada para os recursos do Lab 21."
  type        = string
  default     = "us-east-1"
  nullable    = false

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Este laboratorio utiliza exclusivamente a Regiao us-east-1."
  }
}

variable "expected_account_id" {
  description = "ID da conta AWS autorizada para provisionamento e cleanup."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "Informe o ID da conta AWS como uma string de exatamente 12 digitos."
  }
}

variable "owner" {
  description = "Identificacao do responsavel utilizada na tag Owner."
  type        = string
  default     = "itamarsb"
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.owner)) > 0 &&
      length(var.owner) <= 128 &&
      var.owner == trimspace(var.owner)
    )
    error_message = "Owner deve conter entre 1 e 128 caracteres, sem espacos nas extremidades."
  }
}
