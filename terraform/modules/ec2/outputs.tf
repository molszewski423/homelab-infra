output "instance_id" {
  value = aws_instance.ringcatch.id
}

output "public_ip" {
  value = aws_eip.ringcatch.public_ip
}

output "availability_zone" {
  value = aws_instance.ringcatch.availability_zone
}
