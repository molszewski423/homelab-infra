module "networking" {
  source  = "./modules/networking"
  home_ip = var.home_ip
}

module "ec2" {
  source = "./modules/ec2"

  ami_id              = var.ami_id
  instance_type       = var.instance_type
  key_name            = var.key_name
  public_key_path     = var.public_key_path
  security_group_id   = module.networking.security_group_id
  data_volume_size_gb = var.data_volume_size_gb
  root_volume_size_gb = var.root_volume_size_gb
}
