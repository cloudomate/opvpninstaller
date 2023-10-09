locals {
key_path_public="~/.ssh/onkey.pub"
prefix="ovpn"
flavor="s6.large.2"
vpc_cidr = "192.168.0.0/16" 
private_cidr = "192.168.1.0/24"
primary_dns= "100.125.3.250" 
secondary_dns= "100.125.2.14"
master_az="ae-ad-1a"
subnet_id= g42cloud_vpc_subnet.private.id
}

data "g42cloud_images_image" "ubuntu2004" {
  name = "Ubuntu 20.04 server 64bit"
  most_recent = true
  visibility = "public"
}

resource "g42cloud_compute_keypair" "keypair" {
  name       = "${local.prefix}-ssh-key"
  public_key = file(local.key_path_public)
}

resource "g42cloud_networking_secgroup" "master" {
  name        = "${local.prefix}-master"
}

resource "g42cloud_networking_secgroup_rule" "ssl" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = g42cloud_networking_secgroup.master.id
}


resource "g42cloud_networking_secgroup_rule" "ssl-alt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 943
  port_range_max    = 943
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = g42cloud_networking_secgroup.master.id
}


resource "g42cloud_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = g42cloud_networking_secgroup.master.id
}

resource "g42cloud_networking_secgroup_rule" "udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 1194
  port_range_max    = 1194
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = g42cloud_networking_secgroup.master.id
}



resource "g42cloud_compute_instance" "openvpn-as" {  
  name              = "openvpn-as-01"
  image_id          = data.g42cloud_images_image.ubuntu2004.id 
  flavor_id         = local.flavor
  security_group_ids   = [g42cloud_networking_secgroup.master.id]
  availability_zone = local.master_az
  system_disk_type  = "SSD"
  system_disk_size  = 100
  key_pair        = "${local.prefix}-ssh-key"
  # user_data = base64encode(file("start.sh"))

  network {
    uuid              = local.subnet_id
    source_dest_check = false
  }
}


resource "g42cloud_vpc" "vpc" {
  name = "${local.prefix}-vpc"
  cidr = local.vpc_cidr
}


resource "g42cloud_vpc_subnet" "private" {
  name       = "${local.prefix}-private"
  cidr       = local.private_cidr
  gateway_ip = cidrhost(local.private_cidr,1)
  vpc_id     = g42cloud_vpc.vpc.id
  primary_dns = local.primary_dns
  secondary_dns = local.secondary_dns
}


resource "g42cloud_vpc_eip" "eip" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    share_type = "PER"
    name = "opvpn-eip"
    size        = 300
    charge_mode = "traffic"
  }
}

resource "g42cloud_compute_eip_associate" "associated" {
  public_ip   = g42cloud_vpc_eip.eip.address
  instance_id = g42cloud_compute_instance.openvpn-as.id
}