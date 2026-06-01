terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Uncomment once S3 bucket exists:
  # backend "s3" {
  #   bucket = "ringcatch-terraform-state"
  #   key    = "aws/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "ringcatch"
      ManagedBy = "terraform"
      Owner     = "molszewski423"
    }
  }
}
