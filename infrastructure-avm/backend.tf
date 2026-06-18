terraform {
  backend "azurerm" {
    resource_group_name  = "rg-aeroinbox-tfstate"
    storage_account_name = "staeroinboxtfstate"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
    use_azuread_auth     = true
  }
}
