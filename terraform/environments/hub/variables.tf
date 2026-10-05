variable "subscription_id" {
  description = "Azure subscription ID for the hub"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "uaenorth"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)

  default = {
    environment = "hub"
    managed_by  = "terraform"
  }
}
