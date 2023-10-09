locals {
key_path_public="~/.ssh/onkey.pub"
key_path_private="/home/ysj/.ssh/onkey"
prefix="ovpn"
vm_szie="Standard_B1ls"
vnet_cidr = "192.168.0.0/16" 
private_cidr = "192.168.1.0/24"
port=1194
proto="udp"
base_config_file=file("/home/ysj/coderepo/openvpn/client-configs/base.conf")
ovpn_config_file_path="/home/ysj/coderepo/openvpn/client1.ovpn"
}

resource "azurerm_resource_group" "opvpn" {
  name     = "vpn-resources"
  location = "Central India"
}

data "local_file" "pem_key" {
  filename = local.key_path_private
}


resource "azurerm_virtual_network" "opvpn" {
  name                = "opvpn-network"
  address_space       = [local.vnet_cidr]
  location            = azurerm_resource_group.opvpn.location
  resource_group_name = azurerm_resource_group.opvpn.name
}

resource "azurerm_subnet" "opvpn" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.opvpn.name
  virtual_network_name = azurerm_virtual_network.opvpn.name
  address_prefixes     = [local.private_cidr]
}

resource "azurerm_network_interface" "opvpn" {
  name                = "opvpn-nic"
  location            = azurerm_resource_group.opvpn.location
  resource_group_name = azurerm_resource_group.opvpn.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.opvpn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.openvpn.id
  }
}

resource "azurerm_linux_virtual_machine" "openvpn" {
  name                = "opvpn-machine"
  resource_group_name = azurerm_resource_group.opvpn.name
  location            = azurerm_resource_group.opvpn.location
  size                = local.vm_szie
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.opvpn.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(local.key_path_public)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  custom_data = filebase64("/home/ysj/coderepo/openvpn/openvpnas.sh")
}

resource "azurerm_network_security_group" "opvpn" {
  name = "openvpn-nsg"
  resource_group_name = azurerm_resource_group.opvpn.name
  location            = azurerm_resource_group.opvpn.location
  security_rule {
    name = "ssh"
    protocol = "Tcp"
    direction = "Inbound"
    priority = 100
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    access = "Allow"
  }
  security_rule {
    name = "openvpn"
    protocol = "Udp"
    direction = "Inbound"
    priority = 200
    source_port_range = "*"
    destination_port_range = "1194"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    access = "Allow"
  }
  security_rule {
    name = "https"
    protocol = "Tcp"
    direction = "Inbound"
    priority = 300
    source_port_range = "*"
    destination_port_range = "443"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    access = "Allow"
  }
}

resource "azurerm_network_interface_security_group_association" "opvpn" {
  network_security_group_id = azurerm_network_security_group.opvpn.id
  network_interface_id = azurerm_network_interface.opvpn.id
}


resource "azurerm_public_ip" "openvpn" {
  name                = "openvpnpublicip"
  resource_group_name = azurerm_resource_group.opvpn.name
  location            = azurerm_resource_group.opvpn.location
  allocation_method   = "Dynamic"
  idle_timeout_in_minutes = 30
  tags = {
    environment = "Production"
  }
}

resource "local_file" "client1" {
  content  = format("%s %s %s", "${local.base_config_file}","\nremote ${data.azurerm_public_ip.openvpn.ip_address} ${local.port}\n", ssh_resource.client_config.result)
  filename = local.ovpn_config_file_path
}

resource "ssh_resource" "client_config" {
  depends_on = [
       azurerm_linux_virtual_machine.openvpn,azurerm_network_interface_security_group_association.opvpn,data.azurerm_public_ip.openvpn
  ]
  host =  data.azurerm_public_ip.openvpn.ip_address
  commands = ["sudo cat /etc/openvpn/easy-rsa/client1.ovpn"]
  user        = "adminuser"
  private_key = data.local_file.pem_key.content
  timeout     = "6m"
}


data "azurerm_public_ip" "openvpn" {
  name                = azurerm_public_ip.openvpn.name
  resource_group_name = azurerm_resource_group.opvpn.name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.openvpn.ip_address
}