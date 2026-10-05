variable "project_name" {
  description = "Nome do projeto recebido do modulo raiz."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,49}$", var.project_name))
    error_message = "project_name deve ter de 3 a 50 caracteres: letras minusculas, numeros ou hifens, iniciando por letra."
  }
}

variable "environment" {
  description = "Ambiente recebido do modulo raiz."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser dev, staging ou prod."
  }
}

variable "component_name" {
  description = "Nome do componente desta chamada do modulo."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.component_name))
    error_message = "component_name deve ter de 3 a 30 caracteres: letras minusculas, numeros ou hifens, iniciando por letra."
  }
}

variable "replica_count" {
  description = "Quantidade de replicas registrada como dado didatico."
  type        = number
  default     = 1
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
  description = "Indicador de monitoramento registrado como dado didatico."
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "Metadados adicionais recebidos do modulo raiz."
  type        = map(string)
  default     = {}
  nullable    = false
}
