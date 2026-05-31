############################
# Frontend-Variablen
############################

variable "vm_count" {
  type        = number
  default     = 1
  description = "Anzahl der VMs, die erstellt werden sollen"
}

variable "instance_name" {
  type        = string
  description = "Basis-Name der Instanz(en), z.B. 'webserver'"
  default     = "myapp2"
}

variable "image_name" {
  type        = string
  description = "Name des Packer-Images, das deployed werden soll"
  default     = "myapp2-v1"
}

variable "flavor" {
  type        = string
  description = "OpenStack Flavor (CPU/RAM/Disk-Größe)"
  default     = "gp1.small"
}

variable "enable_floating_ip" {
  type        = bool
  default     = true
  description = "Für jede VM eine Floating IP anlegen und assoziieren"
}

variable "allowed_tcp_ports" {
  type        = list(number)
  default     = []
  description = "Zusätzliche öffentliche TCP-Ports (z.B. [80, 443]). Leer = nur SSH (und optional ICMP)."
}

variable "allow_icmp" {
  type        = bool
  default     = true
  description = "Ping (ICMP) erlauben"
}

############################
# Backend-Defaults
############################

variable "key_pair" {
  type        = string
  description = "OpenStack Keypair Name (für SSH, meist fix pro Projekt)"
  default     = ""
}

variable "network_uuid" {
  description = "UUID of the internal network to attach the instance to (NOT the external network)"
  type        = string
  default     = "34a00b87-57ce-42c4-8e1b-9ea8a657ec2e"  
}

variable "floating_ip_pool" {
  description = "Name of the floating IP pool (external network). Leave empty to use default."
  type        = string
  default     = "DHBW"  
}

variable "ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR, aus der SSH erlaubt ist (empfohlen: deine.ip/32)"
}

variable "metadata" {
  type        = map(string)
  default     = {}
  description = "Zusätzliche Metadata für die Instanzen"
}
