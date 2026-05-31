# Terraform  -  RingCatch AWS Infrastructure

Provisions the EC2 instance, security group, EBS volumes, Elastic IP,
and key pair for the RingCatch hybrid AWS deployment.

## Prerequisites

```bash
# Install Terraform
sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, region (us-east-1), output (json)
```

## Usage

```bash
cd homelab-infra/terraform

# 1. Copy example vars and fill in your home IP
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars  -  set home_ip to output of: curl ifconfig.me

# 2. Initialise (downloads AWS provider)
terraform init

# 3. Preview what will be created
terraform plan

# 4. Apply (creates real AWS resources  -  costs money)
terraform apply

# 5. Get SSH command
terraform output ssh_command
```

## What Gets Created

| Resource | Details |
|---|---|
| `aws_key_pair` | Uploads `~/.ssh/id_ed25519.pub` to AWS |
| `aws_security_group` | SSH from home IP only, Tailscale UDP, all outbound |
| `aws_instance` | t3.small, Ubuntu 22.04, Podman + Tailscale pre-installed |
| `aws_eip` | Elastic IP  -  stable public IP across reboots |
| `aws_ebs_volume` | 10GB gp3, encrypted  -  for PostgreSQL data |
| `aws_volume_attachment` | Attaches data volume at `/dev/xvdb` |

## After Apply

```bash
# SSH in
$(terraform output -raw ssh_command)

# Format and mount the data volume (first time only)
sudo mkfs.ext4 /dev/xvdb
sudo mkdir -p /data
sudo mount /dev/xvdb /data
echo '/dev/xvdb /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Join Tailscale
sudo tailscale up --hostname=ringcatch-aws
```

Then follow the deployment steps in `../docs/AWS-MIGRATION.md` (ringcatch-agency repo).

## Destroy Everything

```bash
terraform destroy
# Confirms before deleting  -  stops billing immediately
```

## Module Structure

```
terraform/
├── main.tf                   # Root  -  wires modules together
├── providers.tf              # AWS provider + Terraform version
├── variables.tf              # All input variables
├── outputs.tf                # EC2 IP, SSH command, etc.
├── terraform.tfvars.example  # Template  -  copy to terraform.tfvars
├── .gitignore                # Excludes state, .tfvars, .terraform/
└── modules/
    ├── networking/           # Security group
    └── ec2/                  # Instance, EIP, EBS volumes, key pair
```

## Future: S3 State Backend

When ready to store state remotely (team use, CI/CD):

```hcl
# Uncomment in providers.tf:
backend "s3" {
  bucket = "ringcatch-terraform-state"
  key    = "aws/terraform.tfstate"
  region = "us-east-1"
}
```

Create the S3 bucket first:
```bash
aws s3 mb s3://ringcatch-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket ringcatch-terraform-state \
  --versioning-configuration Status=Enabled
```
