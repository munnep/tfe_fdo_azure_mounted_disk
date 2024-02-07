output "client_public_ip" {
  value = "ssh adminuser@${azurerm_public_ip.client.ip_address}"
}

output "tfe_public_ip" {
  value = "ssh adminuser@${azurerm_public_ip.tfe_instance.ip_address}"
}

output "tfe_appplication" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}"
}

output "ssh_tfe_server" {
  value = "ssh adminuser@${var.dns_hostname}.${var.dns_zonename}"
}
