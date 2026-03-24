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

resource "aws_security_group" "asg_sg" {
  name_prefix = "asg-sg-"
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

resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-template-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.asg_sg.id]

  user_data = base64encode(var.os == "ubuntu" ? local.ubuntu_script : local.amazon_script)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "app-asg-unified"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = var.public_subnets

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ASG-Instance-Unified"
    propagate_at_launch = true
  }
}