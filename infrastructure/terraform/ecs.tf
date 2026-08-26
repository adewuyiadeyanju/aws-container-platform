resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}-fieldops-api"
  retention_in_days = 3
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

resource "aws_ecs_task_definition" "fieldops" {
  family                   = "${local.name_prefix}-fieldops-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "fieldops-api"
      image     = "${aws_ecr_repository.fieldops.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.main.address
        },
        {
          name  = "DATABASE_PORT"
          value = "5432"
        },
        {
          name  = "DATABASE_NAME"
          value = "fieldops"
        },
      ]

      secrets = [
        {
          name      = "DATABASE_USERNAME"
          valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "fieldops"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-fieldops-api"
  }
}

resource "aws_ecs_service" "fieldops" {
  name            = "${local.name_prefix}-fieldops-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.fieldops.arn

  desired_count = 2
  launch_type   = "FARGATE"

  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.fieldops.arn
    container_name   = "fieldops-api"
    container_port   = 8080
  }

  network_configuration {
    subnets = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  tags = {
    Name = "${local.name_prefix}-fieldops-api"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_iam_role_policy.ecs_task_exec
  ]
}