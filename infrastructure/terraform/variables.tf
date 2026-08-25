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

variable "github_repository_owner" {
  description = "Github repository owner's username."
  type        = string
  default     = "adewuyiadeyanju"
}

variable "github_repository_name" {
  description = "Github repository name."
  type        = string
  default     = "aws-container-platform"
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID used in OIDC subject claims."
  type        = string
  default     = "299310860"
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID used in OIDC subject claims."
  type        = string
  default     = "1346002853"
}

variable "ecr_repository_name" {
  description = "Amazon ECR repository name."
  type        = string
  default     = "fieldops-api"
}