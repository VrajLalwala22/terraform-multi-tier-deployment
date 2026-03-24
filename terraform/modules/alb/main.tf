resource "aws_lb" "app_lb" {
  load_balancer_type = "application"
  subnets            = var.public_subnets
}