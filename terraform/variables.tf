variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI (us-east-1)"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
  default     = "ringcatch-key"
}

variable "public_key_path" {
  description = "Path to local SSH public key to upload to AWS"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "home_ip" {
  description = "Your home public IP for SSH access (curl ifconfig.me)"
  type        = string
  # Set in terraform.tfvars — never hardcode here
}

variable "data_volume_size_gb" {
  description = "Size of EBS data volume in GB"
  type        = number
  default     = 10
}

variable "root_volume_size_gb" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 20
}
