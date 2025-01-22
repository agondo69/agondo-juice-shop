module "naming" {
  source = "Azure/naming/azurerm"

  suffix = [var.workload, var.environment, var.location]
}

resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = module.naming.resource_group.name
}

module "laws" {
  source             = "Azure/avm-res-operationalinsights-workspace/azurerm"

  name                                      = module.naming.log_analytics_workspace.name
  resource_group_name                       = azurerm_resource_group.rg.name
  location                                  = var.location

  log_analytics_workspace_retention_in_days = 30
  log_analytics_workspace_sku               = "PerGB2018"

  enable_telemetry                          = false
}

resource "azurerm_container_app_environment" "cae" {
  location            = var.location
  name                = module.naming.container_app_environment.name
  resource_group_name = azurerm_resource_group.rg.name

  log_analytics_workspace_id = module.laws.resource_id
}

module "ca" {
  source                                = "Azure/avm-res-app-containerapp/azurerm"

  name                                  = module.naming.container_app.name
  resource_group_name                   = azurerm_resource_group.rg.name

  container_app_environment_resource_id = azurerm_container_app_environment.cae.id

  enable_telemetry = false

  revision_mode                         = "Single"
  template = {
    containers = [
      {
        name   = "juice-shop"
        memory = "1Gi"
        cpu    = 0.5
        image  = var.docker_image
      },
    ]
  }
  ingress = {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = 3000
    traffic_weight = [{
      latest_revision = true
      percentage      = 100
    }]
  }
}