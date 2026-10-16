# CodePipeline encrypts its artifacts with the account's AWS-managed S3 key unless told otherwise.
data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # The bucket Elastic Beanstalk keeps its application bundles in.
  eb_bucket_arn = "arn:aws:s3:::elasticbeanstalk-${local.region}-${local.account_id}"

  # An AWS-owned bucket of platform files and templates that deployments read.
  eb_env_resources_bucket_arn = "arn:aws:s3:::elasticbeanstalk-env-resources-${local.region}"

  # Another AWS-owned bucket: the environment's template pulls the platform's startup scripts and
  # hooks from it (stalks/eb_docker_amazon_linux_2023_...). Without read access the deploy fails with
  # "S3 error: Access Denied", because the bucket is in another account and needs an allow on our side.
  eb_platform_assets_bucket_arn = "arn:aws:s3:::elasticbeanstalk-platform-assets-${local.region}"

  # AWS's own regional bucket (note: no account number). Elastic Beanstalk stores each environment's compiled
  # CloudFormation template here (environments/<id>/compiledEnvironmentTemplates/...), and CloudFormation reads
  # it with the deploying role's permissions. THIS was the "S3 error: Access Denied", found with a CloudTrail
  # data-event trail on 2026-10-14.
  eb_regional_bucket_arn = "arn:aws:s3:::elasticbeanstalk-${local.region}"

  eb_application_arn = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:application/${var.eb_application_name}"
  eb_version_arn     = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:applicationversion/${var.eb_application_name}/*"
  eb_environment_arn = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:environment/${var.eb_application_name}/${var.eb_environment_name}"

  eb_instance_role_arn    = "arn:aws:iam::${local.account_id}:role/${var.eb_instance_role_name}"
  eb_instance_profile_arn = "arn:aws:iam::${local.account_id}:instance-profile/${var.eb_instance_profile_name}"
  eb_service_role_arn     = "arn:aws:iam::${local.account_id}:role/${var.eb_service_role_name}"
}

# Build role: write its own logs and read and write the pipeline's artifacts. Nothing else.
resource "aws_iam_role" "codebuild" {
  name = "${var.name}-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "build"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.build.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketAcl", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.artifacts.arn
      }
    ]
  })
}

# Pipeline role: run this build project, use the GitHub connection, and deploy to this one
# Elastic Beanstalk environment.
#
# The Elastic Beanstalk deploy permissions are the part most likely to need adjusting. If the
# first run fails with AccessDenied, the pipeline's error names the missing action.
resource "aws_iam_role" "pipeline" {
  name = "${var.name}-pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "pipeline" {
  name = "pipeline"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Artifacts"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectAcl", "s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetBucketVersioning", "s3:PutObject"]
        Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Sid      = "Build"
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.this.arn
      },
      {
        Sid    = "GitHubConnection"
        Effect = "Allow"
        Action = ["codeconnections:UseConnection"]
        Resource = var.connection_arn
      },
      {
        Sid    = "GitHubConnectionLegacyName"
        Effect = "Allow"
        Action = ["codestar-connections:UseConnection"]
        Resource = replace(var.connection_arn, ":codeconnections:", ":codestar-connections:")
      },
      {
        Sid    = "DeployWrite"
        Effect = "Allow"
        Action = ["elasticbeanstalk:CreateApplicationVersion", "elasticbeanstalk:UpdateEnvironment"]
        Resource = [local.eb_application_arn, local.eb_version_arn, local.eb_environment_arn]
      },
      {
        Sid    = "DeployRead"
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:Describe*",
          "elasticbeanstalk:List*",
          "cloudformation:Describe*",
          "cloudformation:GetTemplate",
          "autoscaling:Describe*",
          "ec2:Describe*",
          "elasticloadbalancing:Describe*"
        ]
        Resource = "*"
      },
      {
        # TEMPORARY for UAT: matches what the recruitment pipeline's role is allowed on this bucket,
        # including rewriting the bucket policy (PutBucketPolicy, PutBucketAcl, PutBucketOwnershipControls).
        # That lets this role change who can read every portal's bundles. Narrow or remove those three
        # once the first deployment works and we know which one Elastic Beanstalk really needs.
        Sid      = "DeployBundle"
        Effect   = "Allow"
        Action   = ["s3:GetObject*", "s3:PutObject", "s3:PutObjectAcl", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucket*", "s3:PutBucketPolicy", "s3:PutBucketAcl", "s3:PutBucketOwnershipControls"]
        Resource = [local.eb_bucket_arn, "${local.eb_bucket_arn}/*"]
      },
      {
        # The pipeline's build artifacts are encrypted with this key (SSE-KMS), so reading them back
        # during a deploy needs permission to use it.
        Sid      = "ArtifactKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = data.aws_kms_alias.s3.target_key_arn
      },
      {
        Sid      = "DeployPlatformFiles"
        Effect   = "Allow"
        Action   = ["s3:GetObject*", "s3:ListBucket", "s3:GetBucket*"]
        Resource = [
          local.eb_env_resources_bucket_arn,
          "${local.eb_env_resources_bucket_arn}/*",
          local.eb_platform_assets_bucket_arn,
          "${local.eb_platform_assets_bucket_arn}/*",
          local.eb_regional_bucket_arn,
          "${local.eb_regional_bucket_arn}/environments/*"
        ]
      },
      {
        # The deploy action checks the environment's instance profile and hands its roles to
        # Elastic Beanstalk. Limited to this portal's instance role and the shared service role.
        Sid      = "DeployRoles"
        Effect   = "Allow"
        Action   = ["iam:GetInstanceProfile", "iam:GetRole", "iam:PassRole"]
        Resource = [local.eb_instance_role_arn, local.eb_instance_profile_arn, local.eb_service_role_arn]
      },
      {
        Sid      = "DeployListProfiles"
        Effect   = "Allow"
        Action   = ["iam:ListInstanceProfiles", "iam:ListInstanceProfilesForRole"]
        Resource = "*"
      },
      {
        # The environment streams its logs to CloudWatch, so the deploy action creates and
        # configures this environment's own log groups.
        Sid    = "DeployLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:TagResource"]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/elasticbeanstalk/${var.eb_environment_name}/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/elasticbeanstalk/${var.eb_environment_name}/*:*"
        ]
      },
      {
        # Every Elastic Beanstalk environment is a CloudFormation stack, and a deploy updates it.
        # Limited to this environment's own stack.
        Sid      = "DeployStack"
        Effect   = "Allow"
        Action   = ["cloudformation:*"]
        Resource = "arn:aws:cloudformation:${local.region}:${local.account_id}:stack/awseb-${var.eb_environment_id}-stack/*"
      },
      {
        Sid      = "DeployTemplateChecks"
        Effect   = "Allow"
        Action   = ["cloudformation:ValidateTemplate", "cloudformation:GetTemplateSummary"]
        Resource = "*"
      },
      {
        # A deploy pauses this environment's Auto Scaling group while it swaps the version, then resumes it.
        # Limited to this environment's own group.
        Sid    = "DeployAutoScaling"
        Effect = "Allow"
        Action = [
          "autoscaling:SuspendProcesses",
          "autoscaling:ResumeProcesses",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:SetInstanceHealth",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:EnterStandby",
          "autoscaling:ExitStandby"
        ]
        Resource = "arn:aws:autoscaling:${local.region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/awseb-${var.eb_environment_id}-stack-AWSEBAutoScalingGroup-*"
      },
      {
        Sid      = "DeployLogsDescribe"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      }
    ]
  })
}
