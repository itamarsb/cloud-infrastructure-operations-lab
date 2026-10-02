variable "aws_profile" {
  description = "Perfil AWS CLI configurado para autenticacao temporaria."
  type        = string
  default     = "cloud-operations-lab"
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.aws_profile)) > 0 &&
      var.aws_profile == trimspace(var.aws_profile)
    )
    error_message = "Informe um perfil AWS sem espacos nas extremidades."
  }
}

variable "aws_region" {
  description = "Regiao AWS utilizada pelo LAB 20."
  type        = string
  default     = "us-east-1"
  nullable    = false

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Este laboratorio utiliza a Regiao us-east-1."
  }
}

variable "expected_account_id" {
  description = "Conta AWS permitida para as operacoes do provider."
  type        = string
  default     = "412381774441"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "O identificador da conta AWS deve conter 12 digitos."
  }
}

variable "shared_vpc_id" {
  description = "Identificador da VPC compartilhada do Lab 08, consultada sem gerenciamento."
  type        = string
  nullable    = false

  validation {
    condition = can(regex(
      "^vpc-([0-9a-f]{8}|[0-9a-f]{17})$",
      var.shared_vpc_id
    ))
    error_message = "Informe um identificador VPC valido."
  }
}

variable "shared_subnet_id" {
  description = "Identificador da sub-rede publica compartilhada do Lab 08."
  type        = string
  nullable    = false

  validation {
    condition = can(regex(
      "^subnet-([0-9a-f]{8}|[0-9a-f]{17})$",
      var.shared_subnet_id
    ))
    error_message = "Informe um identificador de sub-rede valido."
  }
}

variable "allowed_http_cidr" {
  description = "IPv4 publico atual do operador em formato CIDR /32 para acesso HTTP."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(cidrnetmask(var.allowed_http_cidr)) &&
      can(regex(
        "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/32$",
        var.allowed_http_cidr
      ))
    )
    error_message = "Informe um IPv4 valido com mascara /32. Redes mais amplas e IPv6 nao sao permitidos."
  }
}
