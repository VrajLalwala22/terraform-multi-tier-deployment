terraform {
  required_providers {
    aws   = { source = "hashicorp/aws", version = ">= 5.0" }
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
  filter { name = "name", values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]
  filter { name = "name", values = ["al2023-ami-2023.*-x86_64"] }
}
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693020996"]
  filter { name = "name", values = ["debian-12-amd64-*"] }
}
data "aws_ami" "windows" {
  most_recent = true
  owners      = ["801119661308"]
  filter { name = "name", values = ["Windows_Server-2022-English-Full-Base-*"] }
}
data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"]
  filter { name = "name", values = ["RHEL-9*-x86_64-*"] }
}
data "aws_ami" "suse" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name", values = ["*suse-sles-15*x86_64*"] }
}
data "aws_ami" "macos" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name", values = ["amzn-ec2-macos-14.*-x86_64_mac-*"] }
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
  os_ami_map = {
    "ubuntu"  = data.aws_ami.ubuntu.id
    "amazon"  = data.aws_ami.amazon_linux.id
    "debian"  = data.aws_ami.debian.id
    "windows" = data.aws_ami.windows.id
    "rhel"    = data.aws_ami.rhel.id
    "suse"    = data.aws_ami.suse.id
    "macos"   = data.aws_ami.macos.id
  }
  ami_id = lookup(local.os_ami_map, var.os, data.aws_ami.ubuntu.id)

  base_instance_type = var.preference == "performance" ? "t3.small" : "t3.micro"
  instance_type      = var.os == "macos" ? "mac1.metal" : local.base_instance_type

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
    echo "CloudTier Ubuntu setup complete"
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
    echo "CloudTier Amazon Linux setup complete"
    EOF

  debian_user_data = <<-EOF
    #!/bin/bash
    set -ex
    apt-get update -y
    apt-get install -y git nginx curl
    REPO_URL="${var.repo_url}"
    REPO_DIR="/home/admin/repo"
    git clone "$REPO_URL" "$REPO_DIR"
    chown -R admin:admin "$REPO_DIR"
    cd "$REPO_DIR"
    if [ -f "package.json" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        npm install
    fi
    if [ -f "requirements.txt" ]; then
        apt-get install -y python3-pip
        pip3 install -r requirements.txt --break-system-packages || pip3 install -r requirements.txt
    fi
    if [ -f "index.html" ]; then
        cp -r . /var/www/html/
        systemctl enable --now nginx
    fi
    EOF

  rhel_user_data = <<-EOF
    #!/bin/bash
    set -ex
    dnf update -y
    dnf install -y git nginx curl python3-pip npm
    REPO_URL="${var.repo_url}"
    REPO_DIR="/home/ec2-user/repo"
    git clone "$REPO_URL" "$REPO_DIR"
    chown -R ec2-user:ec2-user "$REPO_DIR"
    cd "$REPO_DIR"
    if [ -f "package.json" ]; then
        npm install
    fi
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt
    fi
    if [ -f "index.html" ]; then
        cp -r . /usr/share/nginx/html/
        systemctl enable --now nginx
    fi
    EOF

  suse_user_data = <<-EOF
    #!/bin/bash
    set -ex
    zypper refresh
    zypper install -y git nginx curl python3-pip npm
    REPO_URL="${var.repo_url}"
    REPO_DIR="/home/ec2-user/repo"
    git clone "$REPO_URL" "$REPO_DIR"
    chown -R ec2-user:ec2-user "$REPO_DIR"
    cd "$REPO_DIR"
    if [ -f "package.json" ]; then
        npm install
    fi
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt --break-system-packages || pip3 install -r requirements.txt
    fi
    if [ -f "index.html" ]; then
        cp -r . /srv/www/htdocs/
        systemctl enable --now nginx
    fi
    EOF

  windows_user_data = <<-EOF
<powershell>
$ErrorActionPreference = "Stop"
Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe" -OutFile "git.exe"
Start-Process "git.exe" -ArgumentList "/SILENT" -Wait
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Git\cmd", "Machine")

Install-WindowsFeature -name Web-Server -IncludeManagementTools

$RepoUrl = "${var.repo_url}"
$RepoDir = "C:\repo"
& "C:\Program Files\Git\cmd\git.exe" clone $RepoUrl $RepoDir

if (Test-Path "$RepoDir\index.html") {
    Copy-Item -Path "$RepoDir\*" -Destination "C:\inetpub\wwwroot\" -Recurse -Force
}
</powershell>
EOF

  macos_user_data = <<-EOF
    #!/bin/bash
    set -ex
    su - ec2-user -c 'brew install git nginx node python'
    REPO_URL="${var.repo_url}"
    REPO_DIR="/Users/ec2-user/repo"
    su - ec2-user -c "git clone $REPO_URL $REPO_DIR"
    cd "$REPO_DIR"
    if [ -f "package.json" ]; then
        su - ec2-user -c "cd $REPO_DIR && npm install"
    fi
    if [ -f "requirements.txt" ]; then
        su - ec2-user -c "cd $REPO_DIR && pip3 install -r requirements.txt --break-system-packages"
    fi
    if [ -f "index.html" ]; then
        su - ec2-user -c "cp -r . /usr/local/var/www/"
        su - ec2-user -c "brew services start nginx"
    fi
    EOF

  user_data_map = {
    "ubuntu"  = local.ubuntu_user_data
    "amazon"  = local.amazon_user_data
    "debian"  = local.debian_user_data
    "windows" = local.windows_user_data
    "rhel"    = local.rhel_user_data
    "suse"    = local.suse_user_data
    "macos"   = local.macos_user_data
  }
  user_data = lookup(local.user_data_map, var.os, local.ubuntu_user_data)
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