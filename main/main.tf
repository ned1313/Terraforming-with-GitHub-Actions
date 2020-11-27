###########################
# CONFIGURATION
###########################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"

    }
  }
}

###########################
# VARIABLES
###########################

variable "region" {
  type        = string
  description = "Region in Azure"
  default     = "eastus"
}

variable "prefix" {
  type        = string
  description = "prefix for naming"
  default     = "gumdrops"
}

###########################
# PROVIDERS
###########################

provider "azurerm" {
  #features = {}
  features {}
}

###########################
# LOCALS
###########################

locals {
  name = "${var.prefix}-demo"
}

###########################
# RESOURCES
###########################

resource "azurerm_resource_group" "vnet" {
  name     = local.name
  location = var.region
}

module "network" {
  source  = "Azure/vnet/azurerm"
  version = "2.3.0"

  resource_group_name = azurerm_resource_group.vnet.name
  vnet_name           = local.name
  address_space       = ["10.0.0.0/16"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_names        = ["subnet1", "subnet2", "subnet3"]

  tags = {
    environment = "North Pole"
    costcenter  = "Elves"
    project     = "Festive Tech Calendar 2020"
  }

  depends_on = [azurerm_resource_group.vnet]
}
