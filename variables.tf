variable "resource_group_name" {
    type = "string"
    description = "The target RG for the deployment."
}

variable "username" {
    type = "string"
    description = "The Lab VM username"
}

variable "password" {
    type = "string"
    description = "The Lab VM password"
}

variable "vm_size" {
    type = "string"
    description = "The size of the Lab VM."
    default = "Standard_D4_v3"
}