output "FQDNs" {
  value = ["Connect to ${azurerm_public_ip.win_pip.fqdn}:3389 with RDP."]
}
