resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints

  dynamic "delegation" {
    for_each = each.value.delegation_service != null ? [1] : []
    content {
      name = coalesce(each.value.delegation_name, "delegation")
      service_delegation {
        name = each.value.delegation_service
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = {
    for subnet_name, subnet in var.subnets :
    subnet_name => subnet
    if subnet.nsg_name != null
  }

  name                = each.value.nsg_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  dynamic "security_rule" {
    for_each = each.value.nsg_rules

    content {
      name      = security_rule.value.name
      priority  = security_rule.value.priority
      direction = security_rule.value.direction
      access    = security_rule.value.access
      protocol  = security_rule.value.protocol

      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
      description                = security_rule.value.description
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = {
    for subnet_name, subnet in var.subnets :
    subnet_name => subnet
    if subnet.nsg_name != null
  }

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

