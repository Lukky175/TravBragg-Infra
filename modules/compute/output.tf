output "ec2_public_ips" {
  value = values(aws_instance.ec2)[*].public_ip
}

output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "argocd_url" {
  value = "http://${aws_instance.master.public_ip}:30080"
}