provider "aws" {
  region = "ap-south-1"
}

# 🔹 DYNAMIC AMI LOOKUPS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 🔹 SSH KEY GENERATION (Professional & Centralized)
resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name_prefix = "ec2-key-"
  public_key      = tls_private_key.my_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.my_key.private_key_pem
  filename        = "${path.root}/ec2_key.pem"
  file_permission = "0400"
}

# 🔹 UNIFIED SMART DEPLOYMENT SCRIPTS
locals {
  ami_id = var.os == "ubuntu" ? data.aws_ami.ubuntu.id : data.aws_ami.amazon_linux.id

  # This logic ensures the instance REPLACES if the Repo URL changes
  # by injecting the URL directly into the user_data
  ubuntu_script = <<-EOF
#!/bin/bash
apt update -y
apt install -y git nginx curl
REPO_DIR="/home/ubuntu/repo"
git clone ${var.repo_url} $REPO_DIR
chown -R ubuntu:ubuntu $REPO_DIR
cd $REPO_DIR
if [ -f "package.json" ]; then
    echo "Node.js detected"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    npm install
fi
if [ -f "index.html" ]; then
    cp -r * /var/www/html/
    systemctl enable --now nginx
fi
EOF

  amazon_script = <<-EOF
#!/bin/bash
dnf update -y
dnf install -y git nginx curl
REPO_DIR="/home/ec2-user/repo"
git clone ${var.repo_url} $REPO_DIR
chown -R ec2-user:ec2-user $REPO_DIR
cd $REPO_DIR
if [ -f "package.json" ]; then
    echo "Node.js detected"
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs
    npm install
fi
if [ -f "index.html" ]; then
    cp -r * /usr/share/nginx/html/
    systemctl enable --now nginx
fi
EOF

  user_data = var.os == "ubuntu" ? local.ubuntu_script : local.amazon_script

  instance_type = (
    var.preference == "performance" ? "t3.small" :
    var.preference == "cost" ? "t3.micro" :
    "t3.micro"
  )
}

module "vpc" {
  source = "./modules/vpc"  
}

# 🔹 1-TIER (EC2 only)
module "ec2" {
 source = "./modules/ec2"

  count = var.tier == "1-tier" ? 1 : 0

  instance_type    = local.instance_type
  repo_url         = var.repo_url
  os               = var.os
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
  ssh_key_name     = aws_key_pair.generated_key.key_name
}

# 🔹 2-TIER (EC2 + RDS)
module "ec2_2tier" {
  source = "./modules/ec2"

  count = var.tier == "2-tier" ? 1 : 0

  instance_type    = local.instance_type
  repo_url         = var.repo_url
  os               = var.os
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
  ssh_key_name     = aws_key_pair.generated_key.key_name
}

module "rds" {
  source = "./modules/rds"

  count = var.tier == "2-tier" ? 1 : 0

  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
}

# 🔹 3-TIER (ALB + ASG + RDS)
module "alb" {
  source = "./modules/alb"

  count = var.tier == "3-tier" ? 1 : 0

  public_subnets = module.vpc.public_subnets
}

module "autoscaling" {
  source = "./modules/autoscaling"

  count = var.tier == "3-tier" ? 1 : 0

  public_subnets  = module.vpc.public_subnets
  ssh_key_name    = aws_key_pair.generated_key.key_name
  repo_url        = var.repo_url
  os              = var.os
  instance_type   = local.instance_type
  vpc_id          = module.vpc.vpc_id
}

module "rds_3tier" {
  source = "./modules/rds"

  count = var.tier == "3-tier" ? 1 : 0

  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
}