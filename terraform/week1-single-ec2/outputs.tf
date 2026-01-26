output "instance_public_ip" {
  description = "Public IPv4 of the EC2 instance"
  value       = aws_instance.server.public_ip
}

output "ssh_command" {
  description = "Example SSH command (adjust username/key path)"
  value       = "ssh -i /path/to/your-key.pem ec2-user@${aws_instance.server.public_ip}"
}

output "ansible_inventory_line" {
  value = "week1 ansible_host=${aws_instance.server.public_ip} ansible_user=ec2-user"
}

