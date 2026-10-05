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
  # (see .github/workflows/terraform-stg.yml, or backend-config.hcl for local use).
  backend "azurerm" {
    key = "stg.terraform.tfstate"
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
module "rg_network_stg" {
  source   = "../../modules/resource-group"
  name     = "rg-network-stg-uaen-01"
  location = var.location
  tags     = var.tags
}

module "rg_stg" {
  source   = "../../modules/resource-group"
  name     = "rg-viwell-stg-uaen-01"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------
# Virtual Network
# ---------------------------------------------------------
module "vnet_stg" {
  source              = "../../modules/vnet"
  name                = "vnet-viwell-stg-uaen-01"
  resource_group_name = module.rg_network_stg.name
  location            = var.location
  address_space       = ["10.20.0.0/16"]

  subnets = {
    "snet-app-stg-uaen-01" = {
      address_prefixes = ["10.20.0.64/26"]

      nsg_name = "nsg-app-stg-uaen-01"

      nsg_rules = [
        {
          name                       = "Allow-HTTPS"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          description                = "Allow HTTPS inbound"
        }
      ]
    }
    "snet-func-stg-uaen-01" = {
      address_prefixes   = ["10.20.2.0/26"]
      delegation_name    = "appservice-delegation"
      delegation_service = "Microsoft.Web/serverFarms"

      nsg_name = "nsg-fun-stg-uaen-01"

      nsg_rules = [
        {
          name                       = "Allow-HTTPS"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          description                = "Allow HTTPS inbound"
        }
      ]
    }
    "snet-pep-stg-uaen-01" = {
      address_prefixes = ["10.20.0.128/26"]
    }
    "snet-db-stg-uaen-01" = {
      address_prefixes   = ["10.20.0.192/27"]
      delegation_name    = "postgres-delegation"
      delegation_service = "Microsoft.DBforPostgreSQL/flexibleServers"

      nsg_name = "nsg-db-stg-uaen-01"

      nsg_rules = [
        {
          name                       = "Allow-PostgreSQL-Outbound"
          priority                   = 100
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "5432"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          description                = "Allow outbound PostgreSQL connectivity for migration"
        }
      ]
    }
  }

  tags = var.tags
}
