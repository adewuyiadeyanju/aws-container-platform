output "ecr_repository_name" {
  description = "Name of the Amazon ECR repository"
  value       = aws_ecr_repository.fieldops.name
}

output "ecr_repository_url" {
  description = "URL of the Amazon ECR repository"
  value       = aws_ecr_repository.fieldops.repository_url
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "vpc_id" {
  description = "ID of the application VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID of the shared NAT Gateway."
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the shared NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "alb_dns_name" {
  description = "DNS name of the FieldOps Application Load Balancer."
  value       = aws_lb.fieldops.dns_name
}

output "alb_url" {
  description = "HTTP URL of the FieldOps Application Load Balancer."
  value       = "http://${aws_lb.fieldops.dns_name}"
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.fieldops.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the FieldOps ECS task definition."
  value       = aws_ecs_task_definition.fieldops.arn
}

output "rds_endpoint" {
  description = "Private endpoint of the FieldOps PostgreSQL RDS instance."
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "Port of the FieldOps PostgreSQL RDS instance."
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "Name of the FieldOps PostgreSQL database."
  value       = aws_db_instance.main.db_name
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master credentials."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "ecs_security_group_id" {
  description = "Security group ID assigned to ECS tasks."
  value       = aws_security_group.ecs.id
}

output "alb_security_group_id" {
  description = "Security group ID assigned to the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "rds_security_group_id" {
  description = "Security group ID assigned to RDS."
  value       = aws_security_group.rds.id
}