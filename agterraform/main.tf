terraform {
  cloud {
    organization = "agondo_juiceshop_terra"
    workspaces {
      name = "juice-shop-app"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "2.0.0"

  convention = "pascal"
  name_parts = ["juice", "shop", "containerapp"]
  separator  = "-"
}

module "resource_group" {
  source  = "Azure/resource-group/azurerm"
  version = "6.0.0"

  name     = module.naming.name
  location = "eastus"
}

module "container_registry" {
  source  = "Azure/container-registry/azurerm"
  version = "4.0.0"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  name                  = "${module.naming.name}acr"
  sku                   = "Basic"
  admin_enabled         = true
}

module "container_app_environment" {
  source  = "Azure/container-apps/azurerm"
  version = "3.0.0"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  name = "${module.naming.name}env"
}

module "container_app" {
  source  = "Azure/container-apps/azurerm"
  version = "3.0.0"

  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  name                     = "${module.naming.name}app"
  container_app_environment_id = module.container_app_environment.id

  configuration {
    ingress {
      external_enabled = true
      target_port      = 3000
    }
  }

  revision {
    containers = [{
      name   = "juice-shop"
      image  = "agondo69/juice-shop:latest"
      cpu    = 0.5
      memory = "1Gi"
    }]
  }
}
