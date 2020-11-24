#############################################################################
# VARIABLES
#############################################################################

variable "location" {
  type    = string
  default = "eastus"
}

variable "naming_prefix" {
  type    = string
  default = "grinch"
}

variable "github_repository" {
    type = string
    default = "Terraforming-with-GitHub-Actions"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "azurerm" {
  version = "~> 2.0"

  features {}
}

provider "azuread" {}

provider "github" {}

##################################################################################
# LOCALS
##################################################################################

locals {
  resource_group_name = "${var.naming_prefix}-${random_integer.sa_num.result}"
  storage_account_name = "${lower(var.naming_prefix)}${random_integer.sa_num.result}"
  service_principal_name = "${var.naming_prefix}-${random_integer.sa_num.result}"
}

##################################################################################
# RESOURCES
##################################################################################

## AZURE AD SP ##

data "azurerm_subscription" "current" {}

data "azuread_client_config" "current" {}

resource "random_password" "gh_actions" {
  length  = 16
  special = true
}

resource "azuread_application" "gh_actions" {
  name = local.service_principal_name
}

resource "azuread_service_principal" "gh_actions" {
  application_id = azuread_application.gh_actions.application_id
}

resource "azuread_service_principal_password" "gh_actions" {
  service_principal_id = azuread_service_principal.gh_actions.id
  value                = random_password.gh_actions.result
  end_date_relative    = "17520h"
}

resource "azurerm_role_assignment" "vnet" {
  scope              = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id       = azuread_service_principal.gh_actions.id
}

# Azure Storage Account

resource "random_integer" "sa_num" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "setup" {
  name     = local.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.setup.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

resource "azurerm_storage_container" "ct" {
  name                 = "terraform-state"
  storage_account_name = azurerm_storage_account.sa.name

}

data "azurerm_storage_account_sas" "state" {
  connection_string = azurerm_storage_account.sa.primary_connection_string
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "17520h")

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
    update  = false
    process = false
  }
}

## GitHub secrets

resource "github_actions_secret" "actions_secret" {
  for_each = {
      STORAGE_ACCOUNT = azurerm_storage_account.sa.name
      ARM_SAS_TOKEN = data.azurerm_storage_account_sas.state.sas
      ARM_CLIENT_ID = azuread_service_principal.gh_actions.application_id
      ARM_CLIENT_SECRET = random_password.gh_actions.result
      ARM_SUBSCRIPTION_ID = data.azurerm_subscription.current.subscription_id
      ARM_TENANT_ID = data.azuread_client_config.current.tenant_id
  }

  repository       = var.github_repository
  secret_name      = each.key
  plaintext_value  = each.value
}


##################################################################################
# OUTPUT
##################################################################################

output "STORAGE_ACCOUNT" {
  value = azurerm_storage_account.sa.name
}

output "ARM_SAS_TOKEN" {
    value = data.azurerm_storage_account_sas.state.sas
}

output "ARM_CLIENT_ID" {
    value = azuread_service_principal.gh_actions.application_id
}

output "ARM_CLIENT_SECRET" {
    value = random_password.gh_actions.result
}

output "ARM_SUBSCRIPTION_ID" {
    value = data.azurerm_subscription.current.subscription_id
}

output "ARM_TENANT_ID" {
    value = data.azuread_client_config.current.tenant_id
}