# ---------------------------------------------------------
# ECS Task Execution Role
# Used by ECS itself to:
# - Pull images from ECR
# - Write logs to CloudWatch
# - Retrieve secrets from Secrets Manager
# ---------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-ecs-task-execution"
    Project     = "aws-container-platform"
    Application = "FieldOps"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


# ---------------------------------------------------------
# ECS Task Execution Managed Policy
# Provides standard ECS execution permissions
# ---------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ---------------------------------------------------------
# ECS Task Execution Secrets Policy
# Allows ECS to retrieve the database secret from
# AWS Secrets Manager when starting the task.
# ---------------------------------------------------------

resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${local.name_prefix}-ecs-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_db_instance.main.master_user_secret[0].secret_arn
      }
    ]
  })
}


# ---------------------------------------------------------
# ECS Task Role
#
# This role is assumed by the application container itself.
#
# It is different from the ECS Task Execution Role.
# ---------------------------------------------------------

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-ecs-task"
    Project     = "aws-container-platform"
    Application = "FieldOps"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


# ---------------------------------------------------------
# ECS Exec / SSM Messages Policy
#
# Required for:
#
# aws ecs execute-command
#
# This allows the ECS Exec agent inside the container
# to establish the SSM communication channels.
# ---------------------------------------------------------

resource "aws_iam_role_policy" "ecs_task_exec" {
  name = "${local.name_prefix}-ecs-task-exec"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]

        Resource = "*"
      }
    ]
  })
}