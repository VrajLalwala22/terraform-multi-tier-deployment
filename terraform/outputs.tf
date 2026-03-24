output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = var.tier == "1-tier" ? "ssh -i ec2_key.pem ${var.os}@${module.ec2[0].public_ip}" : (var.tier == "2-tier" ? "ssh -i ec2_key.pem ${var.os}@${module.ec2_2tier[0].public_ip}" : "N/A (3-tier uses ASG)")
}

output "ec2_public_ip" {
  value = var.tier == "1-tier" ? module.ec2[0].public_ip : (var.tier == "2-tier" ? module.ec2_2tier[0].public_ip : null)
}
