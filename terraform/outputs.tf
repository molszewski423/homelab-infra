output "instance_public_ip" {
  description = "EC2 instance public IP (Elastic IP — stable across reboots)"
  value       = module.ec2.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/ringcatch-key.pem ubuntu@${module.ec2.public_ip}"
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.networking.security_group_id
}
