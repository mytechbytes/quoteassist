variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "capacity" {
  type    = number
  default = 0
}

variable "sku_name" {
  type    = string
  default = "Basic"
}

variable "family" {
  type    = string
  default = "C"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_redis_cache" "this" {
  name                 = var.name
  resource_group_name  = var.resource_group_name
  location             = var.location
  capacity             = var.capacity
  family               = var.family
  sku_name             = var.sku_name
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"
  tags                 = var.tags
}

output "hostname" {
  value = azurerm_redis_cache.this.hostname
}

output "id" {
  value = azurerm_redis_cache.this.id
}
