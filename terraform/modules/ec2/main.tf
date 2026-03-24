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
}

locals {
  ubuntu_script = <<-EOF
#!/bin/bash
# 🔹 Install basic tools
apt update -y
apt install -y git nginx curl

# 🔹 Clone repo to home directory for visibility
REPO_DIR="/home/ubuntu/repo"
git clone ${var.repo_url} $REPO_DIR
chown -R ubuntu:ubuntu $REPO_DIR

# 🔹 SMART ANALYZER & DEPENDENCY INSTALLER
cd $REPO_DIR

# 1. Node.js Detection
if [ -f "package.json" ]; then
    echo "Node.js project detected. Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    npm install
fi

# 2. Python Detection
if [ -f "requirements.txt" ]; then
    echo "Python project detected. Installing requirements..."
    apt install -y python3-pip
    pip3 install -r requirements.txt
fi

# 3. Static Site / Nginx Setup
if [ -f "index.html" ]; then
    echo "Static site detected. Configuring Nginx..."
    cp -r * /var/www/html/
    systemctl enable --now nginx
fi

# 4. Terraform Detection (Just in case)
if ls *.tf >/dev/null 2>&1; then
    echo "Terraform project detected. Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update && apt install terraform
fi

echo "Setup Complete!"
EOF

  amazon_script = <<-EOF
#!/bin/bash
# 🔹 Install basic tools
dnf update -y
dnf install -y git nginx curl

# 🔹 Clone repo to home directory for visibility
REPO_DIR="/home/ec2-user/repo"
git clone ${var.repo_url} $REPO_DIR
chown -R ec2-user:ec2-user $REPO_DIR

# 🔹 SMART ANALYZER & DEPENDENCY INSTALLER
cd $REPO_DIR

# 1. Node.js Detection
if [ -f "package.json" ]; then
    echo "Node.js project detected. Installing Node.js..."
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs
    npm install
fi

# 2. Python Detection
if [ -f "requirements.txt" ]; then
    echo "Python project detected. Installing requirements..."
    dnf install -y python3-pip
    pip3 install -r requirements.txt
fi

# 3. Static Site / Nginx Setup
if [ -f "index.html" ]; then
    echo "Static site detected. Configuring Nginx..."
    cp -r * /usr/share/nginx/html/
    systemctl enable --now nginx
fi

echo "Setup Complete!"
EOF
}

resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = var.vpc_id

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

resource "aws_instance" "app" {
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = aws_key_pair.generated_key.key_name

  user_data = var.os == "ubuntu" ? local.ubuntu_script : local.amazon_script
  user_data_replace_on_change = true
  
  tags = {
    Name = "AppServer-Smart-V3" # Forced replacement
  }
}