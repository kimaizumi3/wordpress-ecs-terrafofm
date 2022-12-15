output "vpc_id" {
  description = "ID of project VPC"
  value       = aws_vpc.vpc.id
}

output "privatesubnet1" {
    value = aws_subnet.privatesubnet1.id 
}

output "privatesubnet2" {
    value = aws_subnet.privatesubnet2.id 
}

output "publicsubnet1" {
    value = aws_subnet.publicsubnet1.id 
}

output "publicsubnet2" {
    value = aws_subnet.publicsubnet2.id 
}