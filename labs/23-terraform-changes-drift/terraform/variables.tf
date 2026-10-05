variable "project_name" {
  description = "Nome do projeto registrado no arquivo de configuracao."
  type        = string
  default     = "cloud-infrastructure-operations-lab"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,49}$", var.project_name))
    error_message = "project_name deve ter de 3 a 50 caracteres, com letras minusculas, numeros e hifens, iniciando por letra."
  }
}

variable "environment" {
  description = "Ambiente didatico registrado no arquivo."
  type        = string
  default     = "dev"
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser dev, staging ou prod."
  }
}

variable "application_version" {
  description = "Versao didatica da configuracao da aplicacao."
  type        = string
  default     = "v1"
  nullable    = false

  validation {
    condition     = contains(["v1", "v2"], var.application_version)
    error_message = "application_version deve ser v1 ou v2."
  }
}

variable "log_level" {
  description = "Nivel de log declarado para a aplicacao didatica."
  type        = string
  default     = "info"
  nullable    = false

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "log_level deve ser debug, info, warn ou error."
  }
}
