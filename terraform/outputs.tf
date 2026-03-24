output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = var.tier == "3-tier" ? "N/A (3-tier uses ASG)" : (var.tier == "1-tier" ? format("ssh -i ec2_key.pem %s@%s", var.os, one(module.ec2[*].public_ip)) : format("ssh -i ec2_key.pem %s@%s", var.os, one(module.ec2_2tier[*].public_ip)))
}

output "ec2_public_ip" {
  value = var.tier == "1-tier" ? one(module.ec2[*].public_ip) : one(module.ec2_2tier[*].public_ip)
}

output "alb_dns_name" {
  value = one(module.alb[*].dns_name)
}
