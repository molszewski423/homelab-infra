variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "ami_id" {
  type    = string
  default = "ami-0c7217cdde317cfec"
}
variable "key_name" {
  type    = string
  default = "ringcatch-key"
}
variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
variable "home_ip" {
  type = string
}
variable "data_volume_size_gb" {
  type    = number
  default = 10
}
variable "root_volume_size_gb" {
  type    = number
  default = 20
}
