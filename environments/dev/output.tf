output "ec2_public_ips" {
  value = module.compute.ec2_public_ips
}

output "master_public_ip" {
  value = module.compute.master_public_ip
}

output "argocd_url" {
  value = module.compute.argocd_url
}
output "master_private_ip" {
  value = module.compute.master_private_ip
}