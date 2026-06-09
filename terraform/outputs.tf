############################
# [CONTRACT] User Accounts Output
############################

# CONTRACT-SCHEMA:
# local.user_accounts = {
#   "<team>-<username>": {
#     type     = "password"
#     ip       = "1.2.3.4"
#     port     = 8080
#     username = "john-doe"
#     auth     = "<password>"
#   }
# }

output "user_accounts" {
  description = "[CONTRACT] User accounts - Struktur siehe Kommentar oben"
  value       = local.user_accounts
  sensitive   = true # Enthält Passwörter
}

############################
# Team-VM Details
############################

output "team_vms" {
  description = "Details aller Team-VMs"
  value = {
    for team in local.teams_list : team => {
      instance_id   = openstack_compute_instance_v2.shared_vm.id
      instance_name = openstack_compute_instance_v2.shared_vm.name
      fixed_ip      = openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v4
      floating_ip   = local.enable_floating_ip ? openstack_networking_floatingip_v2.fip[0].address : null
      url           = local.enable_floating_ip ? "http://${openstack_networking_floatingip_v2.fip[0].address}:8000" : "http://${openstack_compute_instance_v2.shared_vm.network[0].fixed_ip_v4}:8000"
    }
  }
}

output "teams_summary" {
  description = "Übersicht: Teams und User-Anzahl"
  value = {
    for team in local.teams_list : team => length([for uid, u in local.users_map : u if u.team == team])
  }
}
