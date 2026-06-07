terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
  }
}

provider "openstack" {
  cloud = "openstack"
  # Auth via OS_CLOUD + clouds.yaml (oder OS_* env vars)
}

############################
# APP-DEFAULTS (vom App-Entwickler vorgegeben)
############################

locals {
  # Diese Werte sind App-spezifisch und werden vom App-Entwickler definiert
  app_name           = "jupyter-notebook"
  flavor             = "gp1.small"
  key_pair           = "" # Leer = nur Passwort-Auth
  enable_floating_ip = true
  metadata           = {}
}

############################
# USER MANAGEMENT (CONTRACT)
############################

# Flatten users from teams - EXAKT wie im Contract vorgegeben
locals {
  all_users = flatten([
    for team, members in var.users : [
      for member in members : {
        id       = "${team}-${replace(split("@", member.email)[0], ".", "-")}"
        team     = team
        email    = member.email
        username = replace(split("@", member.email)[0], ".", "")
      }
    ]
  ])

  # Eindeutige Teams extrahieren
  unique_teams = distinct([for user in local.all_users : user.team])

  # VM-Anzahl = 1 (eine gemeinsame VM)
  vm_count = 1

  # Liste aller Usernamen und E-Mails
  usernames = [for user in local.all_users : user.username]
  emails    = [for user in local.all_users : user.email]
  user_ids  = [for user in local.all_users : user.id]

  # Map für schnelle Lookup-Operationen
  users_map    = { for user in local.all_users : user.id => user }
  teams_list   = distinct([for user in local.all_users : user.team])
  user_indices = { for idx, user in local.all_users : user.id => idx }
}

# Passwörter für jeden User generieren
resource "random_password" "user_passwords" {
  count   = length(local.all_users)
  length  = 16
  special = true
  # Mindestens: 1 Uppercase, 1 Lowercase, 1 Zahl, 1 Sonderzeichen
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
}

locals {
  # [CONTRACT] User Accounts Output (Online-IDE kompatibel)
  user_accounts = length(local.all_users) > 0 ? {
    for uid, user in local.users_map : uid => {
      type     = "password"
      ip       = local.enable_floating_ip ? openstack_networking_floatingip_v2.fip[0].address : openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v4
      port     = 8000
      username = user.username
      auth     = random_password.user_passwords[local.user_indices[uid]].result
    }
  } : {}
}

# Packer-built image lookup by name (keine IDs hardcoden)
data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

# External network nur nötig, wenn Floating IP aktiviert ist
data "openstack_networking_network_v2" "external" {
  name = var.floating_ip_pool
}

resource "random_id" "suffix" {
  byte_length = 4
}

# -----------------------------------------------------------------------------
# Gemeinsame Instanz (eine VM für alle User)
# -----------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "shared_vm" {
  name        = "${local.app_name}-shared"
  image_id    = data.openstack_images_image_v2.image.id
  flavor_name = local.flavor
  key_pair    = local.key_pair != "" ? local.key_pair : null

  security_groups = [var.shared_secgroup_id]

  timeouts {
    create = "15m"
    delete = "15m"
  }

  network {
    uuid = var.network_uuid
  }

  user_data = templatefile("${path.module}/cloud-init-multi-user.yml.tpl", {
    all_users    = local.all_users
    unique_teams = local.unique_teams
    passwords    = [for p in random_password.user_passwords : p.result]
  })

  metadata = merge(local.metadata, {
    teams = join(",", local.unique_teams)
    users = join(",", local.usernames)
  })
}

# -----------------------------------------------------------------------------
# Optional Floating IP (eine für die gemeinsame VM)
# -----------------------------------------------------------------------------
resource "openstack_networking_floatingip_v2" "fip" {
  count = local.enable_floating_ip ? 1 : 0
  pool  = data.openstack_networking_network_v2.external.name
}

# Warten bis VM vollständig gebootet ist
resource "time_sleep" "wait_for_vm" {
  count           = local.enable_floating_ip ? 1 : 0
  depends_on      = [openstack_compute_instance_v2.shared_vm]
  create_duration = "60s"
}

# Port-ID der VM finden
data "openstack_networking_port_v2" "vm_port" {
  count     = local.enable_floating_ip ? 1 : 0
  device_id = openstack_compute_instance_v2.shared_vm.id
  depends_on = [
    openstack_compute_instance_v2.shared_vm,
    time_sleep.wait_for_vm
  ]
}

# Floating IP Association mit data-basierter Port-ID
resource "openstack_networking_floatingip_associate_v2" "fip_assoc" {
  count       = local.enable_floating_ip ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.fip[0].address
  port_id     = data.openstack_networking_port_v2.vm_port[0].id

  depends_on = [
    data.openstack_networking_port_v2.vm_port,
    time_sleep.wait_for_vm
  ]
}
