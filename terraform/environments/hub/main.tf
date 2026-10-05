terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Partial backend config: resource_group_name, storage_account_name and
  # container_name are supplied at `terraform init` time via -backend-config
  # (see .github/workflows/*.yml, or backend-config.hcl for local use).
  backend "azurerm" {
    key = "hub.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  use_oidc        = true
  # client_id and tenant_id are NOT set here — the provider reads them
  # automatically from ARM_CLIENT_ID / ARM_TENANT_ID environment variables.
  # No client secret is used at all with OIDC.
}

# ---------------------------------------------------------
# Resource Group
# ---------------------------------------------------------
module "rg_hub" {
  source   = "../../modules/resource-group"
  name     = "rg-viwell-hub-uaen-01"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------
# Hub Virtual Network
# ---------------------------------------------------------
module "vnet_hub" {
  source              = "../../modules/vnet"
  name                = "vnet-hub-uaen-01"
  resource_group_name = module.rg_hub.name
  location            = var.location
  address_space       = ["10.10.0.0/16"]

  subnets = {
    "snet-ext-hub-uaen-01" = {
      address_prefixes = ["10.10.0.64/26"]
    }
    "snet-int-hub-uaen-01" = {
      address_prefixes = ["10.10.0.128/26"]
    }
    "snet-appgtw-uaen-01" = {
      address_prefixes = ["10.10.0.192/27"]
    }
  }

  tags = var.tags
}
