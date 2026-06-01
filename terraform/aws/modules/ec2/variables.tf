variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "public_key_path" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "data_volume_size_gb" {
  type = number
}

variable "root_volume_size_gb" {
  type = number
}
