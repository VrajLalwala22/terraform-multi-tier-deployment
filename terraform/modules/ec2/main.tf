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

locals {
  ami_id = var.os == "ubuntu" ? data.aws_ami.ubuntu.id : data.aws_ami.amazon_linux.id
  
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
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2-sg-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = var.ssh_key_name

  user_data = var.os == "ubuntu" ? local.ubuntu_script : local.amazon_script
  user_data_replace_on_change = true
  
  tags = {
    Name = "AppServer-Unified"
  }
}

output "public_ip" {
  value = aws_instance.app.public_ip
}