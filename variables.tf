# token variable
variable "token" {
  description = "packet token"
}

# project id variable (defaults to )
variable "projectid" {
  description = "packet project id"
}

# prefix variable
variable "prefix" {
  default     = "daniele"
  description = "prefix for names"
}

# plan varialbe
variable "plan_arm" {
  description = "Plan for K8s ARM Nodes"
  #default     = "baremetal_2a"
  default = "c2.large.arm"
}

# facility variable
variable "facility" {
  description = "Packet Facility"
  # default     = "ewr1"
  default = "dfw2"
}

# Operating System variable
variable "operating_system" {
  description = "Operating System"
  default     = "debian_9"
}

variable "server_count" {
  description = "Number of servers"
  default     = "3"
}

variable "client_count" {
  description = "Number of clients"
  default     = "3"
}