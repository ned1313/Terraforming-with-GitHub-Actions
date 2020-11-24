terraform {
    backend "azurerm" {
        container_name = "terraform-state"
        key = "network.terraform.tfstate"
    }
}