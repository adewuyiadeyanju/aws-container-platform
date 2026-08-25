variable "aws_region" {
  description = "AWS region for the container platform."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for AWS resources."
  type        = string
  default     = "aws-container-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the GitHub Actions IAM role."
  type        = string
  default     = "adewuyiadeyanju/aws-container-platform"
}

variable "ecr_repository_name" {
  description = "Amazon ECR repository name."
  type        = string
  default     = "fieldops-api"
}