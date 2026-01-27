output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP of bastion host"
}

output "app_private_ip" {
  value       = aws_instance.app.private_ip
  description = "Private IP of app host (reachable via bastion)"
}

output "ssh_proxyjump_hint" {
  value       = <<EOT
ssh -i <PATH_TO_KEY> -J ec2-user@${aws_instance.bastion.public_ip} ec2-user@${aws_instance.app.private_ip}
EOT
  description = "SSH jump command (ProxyJump) to reach the private instance via bastion"
}

