variable "subscription_id" {
  description = "Azure subscription ID for staging/non-prod"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "uaenorth"
}

variable "postgres_administrator_login" {
  description = "PostgreSQL administrator login"
  type        = string
  default     = "psqladmin"
}

variable "postgres_administrator_password" {
  description = "PostgreSQL administrator password (pass via TF_VAR_ or a gitignored *.tfvars, never hardcoded)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)

  default = {
    environment = "staging"
    managed_by  = "terraform"
  }
}

variable "tenant_id" {
  type = string
}