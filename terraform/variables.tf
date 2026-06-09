########################################
# CUSTOM-Variablen (Optional)
# Werden vom User gesetzt
########################################

variable "users" {
  description = "[CONTRACT] Teams mit User-Emails (vom Dozenten übermittelt)"
  type = map(list(object({
    email = string
  })))
  default = {}
}

########################################
# CONTRACT-Variablen (PFLICHT)
# Werden vom Worker/Platform gesetzt
########################################

variable "image_name" {
  description = "@openstack:image:name"
  type        = string
  default     = "jupyter-notebook-vX"
}

variable "network_uuid" {
  description = "@openstack:network:id"
  type        = string
  default     = "34a00b87-57ce-42c4-8e1b-9ea8a657ec2e"
}

variable "floating_ip_pool" {
  description = "@openstack:floating_ip_pool:name"
  type        = string
  default     = "DHBW"
}

variable "shared_secgroup_id" {
  description = "@openstack:security_group:id"
  type        = string
  default     = "4ffaf007-df66-4250-9118-1bd99378d34a"
}
