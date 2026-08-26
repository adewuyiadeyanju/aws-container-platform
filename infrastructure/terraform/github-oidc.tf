# ---------------------------------------------------------
# GitHub Actions OIDC Provider
# ---------------------------------------------------------

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]
}


# ---------------------------------------------------------
# GitHub Actions OIDC Trust Policy
#
# Only the configured GitHub repository and MAIN branch
# can assume this role.
# ---------------------------------------------------------

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository_owner}@${var.github_owner_id}/${var.github_repository_name}@${var.github_repository_id}:ref:refs/heads/main"
      ]
    }
  }
}


# ---------------------------------------------------------
# GitHub Actions IAM Role
# ---------------------------------------------------------

resource "aws_iam_role" "github_actions" {
  name = "${local.name_prefix}-github-actions"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name        = "${local.name_prefix}-github-actions"
    Project     = "aws-container-platform"
    Application = "FieldOps"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}


# ---------------------------------------------------------
# GitHub Actions ECR Policy
#
# Allows the workflow to authenticate to ECR and push
# application images.
# ---------------------------------------------------------

data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    sid    = "ECRAuthentication"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.fieldops.arn
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name   = "${local.name_prefix}-github-actions-ecr"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ecr.json
}


# ---------------------------------------------------------
# GitHub Actions Terraform State Policy
#
# Terraform uses the S3 backend defined in backend.tf.
#
# State bucket:
# aws-container-platform-dev-tfstate-506813471880
#
# Locking is handled using the S3 native lockfile.
# No DynamoDB table is required.
# ---------------------------------------------------------

data "aws_iam_policy_document" "github_actions_terraform_state" {
  statement {
    sid = "TerraformStateBucket"

    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::aws-container-platform-dev-tfstate-506813471880"
    ]
  }

  statement {
    sid = "TerraformStateObjects"

    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::aws-container-platform-dev-tfstate-506813471880/*"
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_terraform_state" {
  name   = "${local.name_prefix}-github-actions-terraform-state"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_terraform_state.json
}


# ---------------------------------------------------------
# GitHub Actions Terraform Infrastructure Policy
#
# Allows Terraform running inside GitHub Actions to manage
# the infrastructure defined by this project.
# ---------------------------------------------------------

data "aws_iam_policy_document" "github_actions_terraform" {

  # -------------------------
  # VPC / Networking
  # -------------------------
  statement {
    sid    = "TerraformNetworking"
    effect = "Allow"

    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteVpc",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateRouteTable",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:ReplaceRoute",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
    ]

    resources = ["*"]
  }


  # -------------------------
  # ECS
  # -------------------------
  statement {
    sid    = "TerraformECS"
    effect = "Allow"

    actions = [
      "ecs:CreateCluster",
      "ecs:DeleteCluster",
      "ecs:DescribeClusters",
      "ecs:UpdateCluster",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:CreateService",
      "ecs:DeleteService",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:ListTagsForResource",
      "ecs:TagResource",
      "ecs:UntagResource"
    ]

    resources = ["*"]
  }


  # -------------------------
  # Elastic Load Balancing
  # -------------------------
  statement {
    sid    = "TerraformLoadBalancing"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]

    resources = ["*"]
  }


  # -------------------------
  # RDS
  # -------------------------
  statement {
    sid    = "TerraformRDS"
    effect = "Allow"

    actions = [
      "rds:CreateDBInstance",
      "rds:DeleteDBInstance",
      "rds:DescribeDBInstances",
      "rds:ModifyDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:DescribeDBSubnetGroups",
      "rds:ModifyDBSubnetGroup",
      "rds:ListTagsForResource",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource"
    ]

    resources = ["*"]
  }


  # -------------------------
  # Secrets Manager
  # -------------------------
  statement {
    sid    = "TerraformSecretsManager"
    effect = "Allow"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecrets",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]

    resources = ["*"]
  }


  # -------------------------
  # CloudWatch Logs
  # -------------------------
  statement {
    sid    = "TerraformCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:ListTagsForResource",
      "logs:TagResource"
    ]

    resources = ["*"]
  }


  # -------------------------
  # ECR
  # -------------------------
  statement {
    sid = "TerraformECR"

    effect = "Allow"

    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DeleteRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:SetRepositoryPolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:ListTagsForResource",
    ]

    resources = ["*"]
  }


  # -------------------------
  # IAM
  #
  # Required because Terraform manages:
  # - ECS task execution role
  # - ECS task role
  # - GitHub Actions role
  # - IAM policies
  # - GitHub OIDC provider
  # -------------------------
  statement {
    sid    = "TerraformIAM"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders"
    ]

    resources = ["*"]
  }


  # -------------------------
  # IAM PassRole
  #
  # Required when ECS uses the task execution role
  # and task role.
  # -------------------------
  statement {
    sid    = "TerraformPassRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_terraform" {
  name   = "${local.name_prefix}-github-actions-terraform"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_terraform.json
}