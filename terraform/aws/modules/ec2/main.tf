# Upload local SSH public key to AWS
resource "aws_key_pair" "ringcatch" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.public_key_path))
}

# EC2 instance
resource "aws_instance" "ringcatch" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ringcatch.key_name
  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true
  }

  # Install base packages on first boot
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y podman podman-compose curl wget git jq htop
    # Create app user
    useradd -m -s /bin/bash ringcatch
    loginctl enable-linger ringcatch
    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
  EOF

  tags = {
    Name = "ringcatch-server"
  }
}

# Elastic IP — keeps the same public IP across reboots
resource "aws_eip" "ringcatch" {
  instance = aws_instance.ringcatch.id
  domain   = "vpc"
}

# Separate EBS data volume for PostgreSQL + backups
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.ringcatch.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "ringcatch-data"
  }
}

# Attach data volume to instance at /dev/xvdb
resource "aws_volume_attachment" "data" {
  device_name = "/dev/xvdb"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.ringcatch.id
}
