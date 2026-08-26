# ============================================================
# GitHub Actions OIDC Provider
# ============================================================

# GitHub's OIDC endpoint is used by GitHub Actions to obtain
# short-lived AWS credentials without storing AWS access keys.

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
#
# IMPORTANT:
# The subject is restricted to this GitHub repository, but not
# to one specific branch/environment. This is intentional because
# GitHub changes the OIDC sub claim for pull requests and for jobs
# that use GitHub Environments. Restricting it to the repository
# prevents other repositories from assuming this role while still
# allowing the CI/CD workflow's Plan, Apply and Verify jobs to
# re-assume the role.
#

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
        # Standard GitHub OIDC subject format
        "repo:${var.github_repository_owner}/${var.github_repository_name}:*",

        # Immutable GitHub OIDC subject format (owner/repository IDs)
        # used by repositories that have opted into immutable subjects.
        "repo:${var.github_repository_owner}@${var.github_owner_id}/${var.github_repository_name}@${var.github_repository_id}:*"
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
# Consolidated GitHub Actions Permissions
# ============================================================
#
# This replaces the previous separate:
#   - github_actions_ecr
#   - github_actions_terraform
#   - github_actions_terraform_state
# policies with one Terraform-managed policy.
#
# The policy contains permissions required by:
#   1. Terraform backend (S3)
#   2. Terraform infrastructure management
#   3. Docker image push/pull to ECR
#   4. ECS deployment
#   5. Verify Deployment workflow steps
#

data "aws_iam_policy_document" "github_actions_permissions" {

  # ----------------------------------------------------------
  # Terraform S3 Backend
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::${var.tfstate_bucket_name}"
    ]
  }

  statement {
    sid    = "TerraformStateObjects"
    effect = "Allow"

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${var.tfstate_bucket_name}/*"
    ]
  }


  # ----------------------------------------------------------
  # EC2 / VPC / Networking
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformNetworking"
    effect = "Allow"

    actions = [
      # Read / discovery
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcs",

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
      "ec2:CreateTags",
      "ec2:DeleteTags"
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
      # Read / discovery
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
  # ECR - Terraform repository management + Docker push/pull
  # ----------------------------------------------------------

  statement {
    sid    = "ECRAuthentication"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "TerraformECR"
    effect = "Allow"

    actions = [
      # Terraform repository discovery / management
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

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.fieldops.arn
    ]
  }


  # ----------------------------------------------------------
  # IAM
  # ----------------------------------------------------------
  # Terraform manages the ECS task roles, execution role,
  # GitHub Actions role, GitHub OIDC provider and inline IAM
  # policies.
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
  # IAM service-linked roles
  # ----------------------------------------------------------
  # Allows Terraform to create AWS service-linked roles if they
  # do not already exist for ECS, ELB or RDS.
  # ----------------------------------------------------------

  statement {
    sid    = "TerraformServiceLinkedRoles"
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"

      values = [
        "ecs.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "rds.amazonaws.com"
      ]
    }
  }


  # ----------------------------------------------------------
  # IAM PassRole
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
# Attach Consolidated GitHub Actions Policy
# ============================================================

resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "${local.name_prefix}-github-actions-terraform"
  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
