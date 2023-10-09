terraform {
  required_providers {
    g42cloud = {
      source  = "g42cloud-terraform/g42cloud"
      version = ">=1.6.0"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = "1.2.0"
    }
  }
}