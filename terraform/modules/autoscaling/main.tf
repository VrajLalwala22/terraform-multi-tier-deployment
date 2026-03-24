resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-template"
  image_id      = "ami-0f5ee92e2d63afc18"  # Amazon Linux (ap-south-1)
  instance_type = "t3.micro"

  user_data = base64encode(<<-EOF
#!/bin/bash
yum install -y git
EOF
  )
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity = 2
  max_size         = 4
  min_size         = 1

  vpc_zone_identifier = var.public_subnets

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
}