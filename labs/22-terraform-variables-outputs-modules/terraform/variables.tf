variable "project_name" {
  description = "Nome do projeto registrado pelos componentes."
  type        = string
  default     = "cloud-infrastructure-operations-lab"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,49}$", var.project_name))
    error_message = "project_name deve ter de 3 a 50 caracteres: letras minusculas, numeros ou hifens, iniciando por letra."
  }
}

variable "environment" {
  description = "Ambiente didatico dos componentes."
  type        = string
  default     = "dev"
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser dev, staging ou prod."
  }
}

variable "replica_count" {
  description = "Quantidade didatica de replicas do componente application."
  type        = number
  default     = 2
  nullable    = false

  validation {
    condition = (
      var.replica_count >= 1 &&
      var.replica_count <= 5 &&
      var.replica_count == floor(var.replica_count)
    )
    error_message = "replica_count deve ser um numero inteiro entre 1 e 5."
  }
}

variable "monitoring_enabled" {
  description = "Indicador didatico de monitoramento dos componentes."
  type        = bool
  default     = true
  nullable    = false
}

variable "common_tags" {
  description = "Metadados adicionais compartilhados pelos componentes."
  type        = map(string)
  default     = {}
  nullable    = false
}
