locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # The bucket Elastic Beanstalk keeps its application bundles in.
  eb_bucket_arn = "arn:aws:s3:::elasticbeanstalk-${local.region}-${local.account_id}"

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
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObject"]
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
        Sid      = "DeployBundle"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [local.eb_bucket_arn, "${local.eb_bucket_arn}/*"]
      }
    ]
  })
}
