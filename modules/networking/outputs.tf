output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  value       = aws_subnet.public.id
  description = "The ID of the public subnet."
}

output "private_subnet_id" {
  value       = aws_subnet.private.id
  description = "The ID of the private subnet."
}
output "nat_gateway_id" {
  value = aws_nat_gateway.nat.id
}