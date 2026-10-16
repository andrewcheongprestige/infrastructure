# TEMPORARY, UAT ONLY. Switched on by var.temporary_broad_deploy_policy.
#
# This copies the permissions of the recruitment pipeline's role (AWSCodePipelineServiceRole-...-
# RecruitmentPortal-UAT), which is known to deploy to Elastic Beanstalk. It is far broader than this
# portal needs: it allows ec2:*, autoscaling:* and iam:PassRole on every role. It exists only to find
# out which permission the narrower policy in iam.tf is missing. Once the deployment works, switch it
# off, add back only what is needed to iam.tf, and delete this file.
resource "aws_iam_role_policy" "pipeline_broad" {
  count = var.temporary_broad_deploy_policy ? 1 : 0

  name = "temporary-broad-deploy"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ElasticBeanstalkBuckets"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:PutBucketAcl",
          "s3:PutBucketOwnershipControls",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectAcl",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject"
        ]
        Resource = [
          local.eb_bucket_arn,
          "${local.eb_bucket_arn}/*",
          local.eb_env_resources_bucket_arn,
          "${local.eb_env_resources_bucket_arn}/*"
        ]
      },
      {
        Sid    = "ElasticBeanstalkFullAccess"
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:*",
          "cloudwatch:*",
          "cloudformation:*",
          "autoscaling:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "sqs:*",
          "sns:*",
          "logs:*",
          "ssm:*",
          "iam:PassRole",
          "iam:GetRole"
        ]
        Resource = "*"
      },
      {
        # Diagnostic only. Step 2: every S3 action, but only on the three buckets the deployment is known to
        # use. If the deploy still works, the earlier gap was an S3 action (not a bucket), and the actions can
        # be trimmed. If it fails, a fourth bucket is involved. Never leave this in place.
        Sid    = "DiagnosticAllS3OnKnownBuckets"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
          local.eb_bucket_arn,
          "${local.eb_bucket_arn}/*",
          local.eb_env_resources_bucket_arn,
          "${local.eb_env_resources_bucket_arn}/*"
        ]
      }
    ]
  })
}
