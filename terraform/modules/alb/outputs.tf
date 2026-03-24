output "dns_name" {
  value = aws_lb.app_lb.dns_name
}

output "alb_arn" {
  value = aws_lb.app_lb.arn
}
