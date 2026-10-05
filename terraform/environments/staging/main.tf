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

# ---------------------------------------------------------
# ACR
# ---------------------------------------------------------
module "acr_stg" {
  source              = "../../modules/acr"
  name                = "acrviwellstguaen01"
  resource_group_name = module.rg_stg.name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags
}

# ---------------------------------------------------------
# AKS
# ---------------------------------------------------------
module "aks_stg" {
  source              = "../../modules/aks"
  name                = "aks-viwell-stg-uaen-01"
  resource_group_name = module.rg_stg.name
  location            = var.location
  dns_prefix          = "aksviwellstg"
  vnet_subnet_id      = module.vnet_stg.subnet_ids["snet-app-stg-uaen-01"]
  acr_id              = module.acr_stg.id
  node_count          = 2
  vm_size             = "Standard_D4as_v5"
  tags                = var.tags
}

# ---------------------------------------------------------
# Private DNS Zones (PostgreSQL + Redis)
# ---------------------------------------------------------
module "postgres_dns_zone_stg" {
  source              = "../../modules/private-dns-zone"
  zone_name           = "privatelink.postgres.database.azure.com"
  resource_group_name = module.rg_stg.name
  vnet_id             = module.vnet_stg.vnet_id
  tags                = var.tags
}

module "redis_dns_zone_stg" {
  source              = "../../modules/private-dns-zone"
  zone_name           = "privatelink.redis.cache.windows.net"
  resource_group_name = module.rg_stg.name
  vnet_id             = module.vnet_stg.vnet_id
  tags                = var.tags
}

# ---------------------------------------------------------
# PostgreSQL Flexible Server
# ---------------------------------------------------------
module "postgresql_stg" {
  source                 = "../../modules/postgresql"
  name                   = "psql-viwell-stg-uaen-01"
  resource_group_name    = module.rg_stg.name
  location               = var.location
  administrator_login    = var.postgres_administrator_login
  administrator_password = var.postgres_administrator_password
  delegated_subnet_id    = module.vnet_stg.subnet_ids["snet-db-stg-uaen-01"]
  private_dns_zone_id    = module.postgres_dns_zone_stg.id
  sku_name               = "GP_Standard_D2ds_v5"
  tags                   = var.tags
}

# ---------------------------------------------------------
# Function App
# ---------------------------------------------------------
module "function_app_stg" {
  source                     = "../../modules/function-app"
  name                       = "func-viwell-stg-uaen-01"
  resource_group_name        = module.rg_stg.name
  location                   = var.location
  storage_account_name       = "stviwellfunuaen01"
  appservice_plan_name       = "asp-viwell-stg-uaen-01"
  vnet_subnet_id             = module.vnet_stg.subnet_ids["snet-func-stg-uaen-01"]
  private_endpoint_subnet_id = module.vnet_stg.subnet_ids["snet-pep-stg-uaen-01"]
  tags                       = var.tags
}

# ---------------------------------------------------------
# Redis Cache
# ---------------------------------------------------------
module "redis_stg" {
  source                     = "../../modules/redis"
  name                       = "redis-viwell-stg-uaen-01"
  resource_group_name        = module.rg_stg.name
  location                   = var.location
  sku_name                   = "Balanced_B0"
  high_availability_enabled  = false
  enable_private_endpoint    = true
  private_endpoint_subnet_id = module.vnet_stg.subnet_ids["snet-pep-stg-uaen-01"]
  private_dns_zone_ids       = [module.redis_dns_zone_stg.id]
  tags                       = var.tags
}

# ---------------------------------------------------------
# Event Hub
# ---------------------------------------------------------
module "eventhub_stg" {
  source                     = "../../modules/eventhub"
  namespace_name             = "evhns-viwell-stg-uaen-01"
  eventhub_name              = "evh-viwell-stg-uaen-01"
  resource_group_name        = module.rg_stg.name
  location                   = var.location
  sku                        = "Standard"
  private_endpoint_subnet_id = module.vnet_stg.subnet_ids["snet-pep-stg-uaen-01"]
  capacity                   = 1
  tags                       = var.tags
}

# ---------------------------------------------------------
# KeyVault
# ---------------------------------------------------------
module "keyvault_stg" {
  source                     = "../../modules/keyvault"
  name                       = "kv-viwell-stg-uaen-01"
  resource_group_name        = module.rg_stg.name
  location                   = var.location
  private_endpoint_subnet_id = module.vnet_stg.subnet_ids["snet-pep-stg-uaen-01"]
  sku_name                   = "standard"
  tenant_id                  = var.tenant_id
  tags                       = var.tags
}

