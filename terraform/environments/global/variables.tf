variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for the global resource group (Front Door itself is a global service, not region-bound)"
  type        = string
  default     = "uaenorth"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    environment = "global"
    managed_by  = "terraform"
  }
}
