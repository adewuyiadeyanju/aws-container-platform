# ============================================================
# GitHub Actions OIDC Provider
# ============================================================

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

  tags = local.common_tags
}


# ============================================================
# GitHub Actions Assume Role Policy
# ============================================================

data "aws_iam_policy_document" "github_actions_assume_role" {

  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository_name}:ref:refs/heads/main"
      ]
    }
  }
}


# ============================================================
# GitHub Actions IAM Role
# ============================================================

resource "aws_iam_role" "github_actions" {
  name = "${local.name_prefix}-github-actions"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-github-actions"
    }
  )
}


# ============================================================
# GitHub Actions ECR Policy
# Used by CI/CD to authenticate and push Docker images.
# ============================================================

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
  name = "${local.name_prefix}-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_actions_ecr.json
}


# ============================================================
# Terraform Management Policy
#
# This is the consolidated permanent policy used by GitHub
# Actions when Terraform manages the AWS infrastructure.
# ============================================================

data "aws_iam_policy_document" "github_actions_terraform" {

  # ----------------------------------------------------------
  # EC2 / VPC / Networking
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformNetworking"
    effect = "Allow"

    actions = [
      # Read
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcs",
      "ec2:DescribeTags",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkInterfaces",

      # VPC
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",

      # Subnets
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",

      # Route tables
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",

      # Internet Gateway
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",

      # NAT Gateway / Elastic IP
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",

      # Security Groups
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",

      # Tags
      "ec2:CreateTags"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # ECS
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformECS"
    effect = "Allow"

    actions = [
      # Read
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTagsForResource",

      # Cluster
      "ecs:CreateCluster",
      "ecs:UpdateCluster",
      "ecs:DeleteCluster",

      # Service
      "ecs:CreateService",
      "ecs:UpdateService",
      "ecs:DeleteService",

      # Task definitions
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",

      # Tags
      "ecs:TagResource",
      "ecs:UntagResource"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # Application Load Balancer
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformLoadBalancing"
    effect = "Allow"

    actions = [
      # Read
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeTags",

      # Load balancer
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",

      # Target groups
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup",

      # Listeners
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyListener",

      # Tags
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # RDS
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformRDS"
    effect = "Allow"

    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBSubnetGroups",
      "rds:ListTagsForResource",

      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",

      "rds:CreateDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",

      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # Secrets Manager
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformSecretsManager"
    effect = "Allow"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # CloudWatch Logs
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",

      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",

      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",

      "logs:TagResource"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # ECR
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformECR"
    effect = "Allow"

    actions = [
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:GetRepositoryPolicy",

      "ecr:CreateRepository",
      "ecr:DeleteRepository",

      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",

      "ecr:PutImageTagMutability",
      "ecr:PutImageScanningConfiguration",

      "ecr:TagResource",
      "ecr:UntagResource"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # IAM
  #
  # Required because Terraform manages:
  # - ECS task roles
  # - ECS execution role
  # - GitHub Actions role
  # - GitHub OIDC provider
  # - inline IAM policies
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformIAM"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",

      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",

      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",

      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProvider",

      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",

      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",

      "iam:TagRole",
      "iam:UntagRole",

      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider"
    ]

    resources = ["*"]
  }


  # ----------------------------------------------------------
  # IAM PassRole
  #
  # Terraform must be able to associate the ECS task and
  # execution roles with the ECS task definition.
  # ----------------------------------------------------------

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


# ============================================================
# Attach Terraform Management Policy
# ============================================================

resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "${local.name_prefix}-github-actions-terraform"
  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_actions_terraform.json
}


# ============================================================
# Terraform S3 Backend State Policy
# ============================================================

data "aws_iam_policy_document" "github_actions_terraform_state" {

  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      "arn:aws:s3:::${var.tfstate_bucket_name}"
    ]
  }

  statement {
    sid    = "TerraformStateObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::${var.tfstate_bucket_name}/*"
    ]
  }
}


resource "aws_iam_role_policy" "github_actions_terraform_state" {
  name = "${local.name_prefix}-github-actions-terraform-state"
  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_actions_terraform_state.json
}