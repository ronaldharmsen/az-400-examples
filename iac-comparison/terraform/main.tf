terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
}

# ---------- Variables ----------
variable "location" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type    = string
  default = "rg-iac-terraform-demo"
}

variable "app_service_plan_name" {
  type    = string
  default = "asp-terraform-demo"
}

variable "web_app_name" {
  type    = string
  default = "app-terraform-demo"
}

variable "storage_account_name" {
  type    = string
  default = "stterraformdemo"
}

variable "sku_name" {
  type    = string
  default = "B1"
}

# ---------- Resource Group ----------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# ---------- Storage Account ----------
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
  https_traffic_only_enabled = true
}

# ---------- App Service Plan (Linux) ----------
resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.sku_name
}

# ---------- Web App ----------
resource "azurerm_linux_web_app" "main" {
  name                = var.web_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "StorageConnectionString" = azurerm_storage_account.main.primary_connection_string
  }
}

# ---------- Outputs ----------
output "web_app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}
