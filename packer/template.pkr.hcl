packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

locals {
  final_image_name = "${var.app_name}-${var.app_version}"
}

source "openstack" "image" {
  image_name        = local.final_image_name
  source_image_name = var.source_image_name
  flavor            = var.flavor
  networks          = var.networks

  security_groups = var.security_groups

  use_blockstorage_volume = var.use_blockstorage_volume
  volume_size             = var.volume_size

  use_floating_ip  = var.use_floating_ip
 

  ssh_ip_version = "4"
  ssh_timeout    = var.ssh_timeout
  ssh_username   = var.ssh_username
}

build {
  sources = ["source.openstack.image"]

  provisioner "shell" {
    script = var.provision_script
  }
}
