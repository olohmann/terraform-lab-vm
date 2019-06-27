variable "resource_group_names" {
    type = list(string)
    description = "The target RG for the deployment."
}

variable "usernames" {
    type = list(string)
    description = "The Lab VM username"
}

variable "passwords" {
    type = list(string)
    description = "The Lab VM password"
}

variable "vm_size" {
    type = string
    description = "The size of the Lab VM."
    default = "Standard_D4_v3"
}

variable "max_count" {
    type = number
    default = 0
}