terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.5.3"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "azurerm" {
  alias                   = "image_factory"
  subscription_id          = var.azure_images_subscription_id
  features {}
}


provider "aws" {
  region = var.region
}

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

data "azurerm_shared_image_version" "ubuntu" {
  provider            = azurerm.image_factory
  name                = "latest"
  image_name          = "hc-base-ubuntu-2404-amd64"
  gallery_name        = "hcbaseGallery"
  resource_group_name = "hc-base-rg-gallery"
}


data "azurerm_shared_image_version" "redhat" {
  provider            = azurerm.image_factory
  name                = "latest"
  image_name          = "hc-base-rhel-9-x86_64"
  gallery_name        = "hcbaseGallery"
  resource_group_name = "hc-base-rg-gallery"
}

resource "azurerm_resource_group" "tfe" {
  name     = var.tag_prefix
  location = "North Europe"
}

resource "azurerm_virtual_network" "tfe" {
  name                = "${var.tag_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
}

resource "azurerm_subnet" "public1" {
  name                 = "${var.tag_prefix}-public1"
  resource_group_name  = azurerm_resource_group.tfe.name
  virtual_network_name = azurerm_virtual_network.tfe.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 1)]
}

resource "azurerm_network_security_group" "tfe" {
  name                = "${var.tag_prefix}-nsg"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name

  security_rule {
    name                       = "https"
    priority                   = "100"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "http"
    priority                   = "110"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ssh"
    priority                   = "120"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


}

resource "azurerm_subnet_network_security_group_association" "tfe-public1" {
  subnet_id                 = azurerm_subnet.public1.id
  network_security_group_id = azurerm_network_security_group.tfe.id
}


resource "azurerm_public_ip" "client" {
  name                = "${var.tag_prefix}-client-publicIP"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_network_interface" "client" {
  name                = "${var.tag_prefix}-client"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name

  ip_configuration {
    name                          = "public_interface"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.client.id
  }
}

resource "azurerm_linux_virtual_machine" "client" {
  name                = "${var.tag_prefix}-client"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  size                = "Standard_D4s_v3"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.client.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_id = var.tfe_os == "ubuntu" ? data.azurerm_shared_image_version.ubuntu.id : data.azurerm_shared_image_version.redhat.id
}

resource "azurerm_public_ip" "tfe_instance" {
  name                = "${var.tag_prefix}-tfe-publicIP"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_network_interface" "tfe" {
  name                = "${var.tag_prefix}-tfe"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name

  ip_configuration {
    name                          = "public_interface"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tfe_instance.id
  }
}

resource "azurerm_linux_virtual_machine" "tfe" {
  name                = "${var.tag_prefix}-tfe"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  size                = "Standard_D4s_v3"
  admin_username      = "adminuser"

  network_interface_ids = [
    azurerm_network_interface.tfe.id,
  ]

  custom_data = base64encode(templatefile("${path.module}/scripts/cloudinit_tfe_server_${var.tfe_os}.yaml", {
    tag_prefix        = var.tag_prefix
    dns_hostname      = var.dns_hostname
    tfe_password      = var.tfe_password
    dns_zonename      = var.dns_zonename
    tfe_release       = var.tfe_release
    tfe_license       = var.tfe_license
    certificate_email = var.certificate_email
    full_chain        = base64encode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}")
    private_key_pem   = base64encode(lookup(acme_certificate.certificate, "private_key_pem"))
  }))


  admin_ssh_key {
    username   = "adminuser"
    public_key = var.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  # source_image_reference {
  #   publisher = local.selected_image.publisher
  #   offer     = local.selected_image.offer
  #   sku       = local.selected_image.sku
  #   version   = local.selected_image.version
  # }

  source_image_id = var.tfe_os == "ubuntu" ? data.azurerm_shared_image_version.ubuntu.id : data.azurerm_shared_image_version.redhat.id  
}


resource "azurerm_managed_disk" "tfe-data" {
  name                 = "${var.tag_prefix}-data-disk"
  resource_group_name  = azurerm_resource_group.tfe.name
  location             = azurerm_resource_group.tfe.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 40
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach-data" {
  managed_disk_id    = azurerm_managed_disk.tfe-data.id
  virtual_machine_id = azurerm_linux_virtual_machine.tfe.id
  lun                = "10"
  caching            = "None"
}

resource "azurerm_managed_disk" "tfe-swap" {
  name                 = "${var.tag_prefix}-swap-disk"
  resource_group_name  = azurerm_resource_group.tfe.name
  location             = azurerm_resource_group.tfe.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach-swap" {
  managed_disk_id    = azurerm_managed_disk.tfe-swap.id
  virtual_machine_id = azurerm_linux_virtual_machine.tfe.id
  lun                = "11"
  caching            = "None"
}

resource "azurerm_managed_disk" "tfe-docker" {
  name                 = "${var.tag_prefix}-docker-disk"
  resource_group_name  = azurerm_resource_group.tfe.name
  location             = azurerm_resource_group.tfe.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 20
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach-docker" {
  managed_disk_id    = azurerm_managed_disk.tfe-docker.id
  virtual_machine_id = azurerm_linux_virtual_machine.tfe.id
  lun                = "12"
  caching            = "None"
}
