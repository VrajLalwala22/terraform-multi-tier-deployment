terraform {
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# DYNAMIC AMI LOOKUPS
# ============================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ============================================================
# CENTRALIZED SSH KEY (one stable key for all deployments)
# ============================================================
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "cloudtier-key"
  public_key = tls_private_key.ssh_key.public_key_openssh

  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.root}/ec2_key.pem"
  file_permission = "0400"
}

# ============================================================
# SMART DEPLOYMENT SCRIPTS
# NOTE: These are in separate locals (Terraform doesn't support
# inline ternary heredoc). repo_url is embedded so any URL
# change auto-triggers instance replacement.
# ============================================================
locals {
  ami_id        = var.os == "ubuntu" ? data.aws_ami.ubuntu.id : data.aws_ami.amazon_linux.id
  instance_type = var.preference == "performance" ? "t3.small" : "t3.micro"

  ubuntu_user_data = <<-EOF
    #!/bin/bash
    set -ex
    apt-get update -y
    apt-get install -y git nginx curl

    REPO_URL="${var.repo_url}"
    REPO_DIR="/home/ubuntu/repo"
    git clone "$REPO_URL" "$REPO_DIR"
    chown -R ubuntu:ubuntu "$REPO_DIR"
    cd "$REPO_DIR"

    if [ -f "package.json" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        npm install
    fi

    if [ -f "requirements.txt" ]; then
        apt-get install -y python3-pip
        pip3 install -r requirements.txt
    fi

    if [ -f "index.html" ]; then
        cp -r . /var/www/html/
        systemctl enable --now nginx
    fi

    echo "CloudTier setup complete: ${var.repo_url}"
    EOF

  amazon_user_data = <<-EOF
    #!/bin/bash
    set -ex
    dnf update -y
    dnf install -y git nginx curl

    REPO_URL="${var.repo_url}"
    REPO_DIR="/home/ec2-user/repo"
    git clone "$REPO_URL" "$REPO_DIR"
    chown -R ec2-user:ec2-user "$REPO_DIR"
    cd "$REPO_DIR"

    if [ -f "package.json" ]; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        dnf install -y nodejs
        npm install
    fi

    if [ -f "requirements.txt" ]; then
        dnf install -y python3-pip
        pip3 install -r requirements.txt
    fi

    if [ -f "index.html" ]; then
        cp -r . /usr/share/nginx/html/
        systemctl enable --now nginx
    fi

    echo "CloudTier setup complete: ${var.repo_url}"
    EOF

  user_data = var.os == "ubuntu" ? local.ubuntu_user_data : local.amazon_user_data
}

# ============================================================
# VPC
# ============================================================
module "vpc" {
  source = "./modules/vpc"
}

# ============================================================
# 1-TIER (Single EC2)
# ============================================================
module "ec2" {
  source = "./modules/ec2"
  count  = var.tier == "1-tier" ? 1 : 0

  ami_id           = local.ami_id
  user_data        = local.user_data
  instance_type    = local.instance_type
  ssh_key_name     = aws_key_pair.ssh_key_pair.key_name
  repo_url         = var.repo_url
  os               = var.os
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
}

# ============================================================
# 2-TIER (EC2 + RDS)
# ============================================================
module "ec2_2tier" {
  source = "./modules/ec2"
  count  = var.tier == "2-tier" ? 1 : 0

  ami_id           = local.ami_id
  user_data        = local.user_data
  instance_type    = local.instance_type
  ssh_key_name     = aws_key_pair.ssh_key_pair.key_name
  repo_url         = var.repo_url
  os               = var.os
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
}

module "rds" {
  source             = "./modules/rds"
  count              = var.tier == "2-tier" ? 1 : 0
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
}

# ============================================================
# 3-TIER (ALB + ASG + RDS)
# ============================================================
module "alb" {
  source         = "./modules/alb"
  count          = var.tier == "3-tier" ? 1 : 0
  public_subnets = module.vpc.public_subnets
}

module "autoscaling" {
  source         = "./modules/autoscaling"
  count          = var.tier == "3-tier" ? 1 : 0
  public_subnets = module.vpc.public_subnets
  ami_id         = local.ami_id
  user_data      = local.user_data
  instance_type  = local.instance_type
  ssh_key_name   = aws_key_pair.ssh_key_pair.key_name
  repo_url       = var.repo_url
  vpc_id         = module.vpc.vpc_id
}

module "rds_3tier" {
  source             = "./modules/rds"
  count              = var.tier == "3-tier" ? 1 : 0
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
}