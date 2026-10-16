locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # The bucket Elastic Beanstalk keeps this account's application bundles and environment files in.
  eb_bucket_arn = "arn:aws:s3:::elasticbeanstalk-${local.region}-${local.account_id}"

  # AWS's own regional bucket (note: no account number). Elastic Beanstalk stores each environment's compiled
  # CloudFormation template here (environments/<id>/compiledEnvironmentTemplates/...), and CloudFormation reads
  # it with the deploying role's permissions. Without read access the deploy fails with
  # "S3 error: Access Denied". Found with a CloudTrail data-event trail on 2026-10-14.
  eb_regional_bucket_arn = "arn:aws:s3:::elasticbeanstalk-${local.region}"

  eb_application_arn = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:application/${var.eb_application_name}"
  eb_version_arn     = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:applicationversion/${var.eb_application_name}/*"
  eb_environment_arn = "arn:aws:elasticbeanstalk:${local.region}:${local.account_id}:environment/${var.eb_application_name}/${var.eb_environment_name}"
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
# The deploy statements were worked out one failure at a time on 2026-10-14. A CloudTrail data-event trail
# recorded every S3 request the role made, and the lists below are limited to what it actually used. If a
# deploy fails with AccessDenied, the error names the missing action.
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
        Sid      = "Artifacts"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObject"]
        Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Sid      = "Build"
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.this.arn
      },
      {
        Sid      = "GitHubConnection"
        Effect   = "Allow"
        Action   = ["codeconnections:UseConnection"]
        Resource = var.connection_arn
      },
      {
        Sid      = "GitHubConnectionLegacyName"
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = replace(var.connection_arn, ":codeconnections:", ":codestar-connections:")
      },
      {
        Sid      = "DeployWrite"
        Effect   = "Allow"
        Action   = ["elasticbeanstalk:CreateApplicationVersion", "elasticbeanstalk:UpdateEnvironment"]
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
        # The deploy copies the new bundle into Elastic Beanstalk's own bucket and tidies up after itself.
        # Narrowing the object paths (resources/environments/<id>/* and so on) is a possible next step.
        Sid      = "DeployBundle"
        Effect   = "Allow"
        Action   = ["s3:GetObject*", "s3:PutObject", "s3:PutObjectAcl", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucket*"]
        Resource = [local.eb_bucket_arn, "${local.eb_bucket_arn}/*"]
      },
      {
        Sid      = "DeployRegionalTemplates"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [local.eb_regional_bucket_arn, "${local.eb_regional_bucket_arn}/environments/*"]
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
        Sid      = "DeployLogsDescribe"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
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
      }
    ]
  })
}
