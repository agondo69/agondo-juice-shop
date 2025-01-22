output "rg_name" {
  description = "Resource Group Name."
  value = azurerm_resource_group.rg.name
}

output "app_fqdn" {
  description = "Fully Qualified Domain Name of the Application."
  value = module.ca.fqdn_url
}