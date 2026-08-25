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