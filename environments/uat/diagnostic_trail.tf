# TEMPORARY DIAGNOSTIC. Delete this whole file (and run terraform apply) once the pipeline deploys.
#
# Logs every S3 object request on the Elastic Beanstalk and CodePipeline buckets, with who made it, the
# exact bucket and key, and the error code. It exists to find the S3 request that fails with
# "S3 error: Access Denied" when the pipeline deploys, which no other log shows.

data "aws_caller_identity" "diag" {}

data "aws_region" "diag" {}

locals {
  diag_trail_name = "client-portal-s3-diagnostic"
}

resource "aws_s3_bucket" "diag" {
  bucket        = "client-portal-diagnostic-trail-${data.aws_caller_identity.diag.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "diag" {
  bucket                  = aws_s3_bucket.diag.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "diag" {
  bucket = aws_s3_bucket.diag.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.diag.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.diag.region}:${data.aws_caller_identity.diag.account_id}:trail/${local.diag_trail_name}"
          }
        }
      },
      {
        Sid       = "CloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.diag.arn}/AWSLogs/${data.aws_caller_identity.diag.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.diag.region}:${data.aws_caller_identity.diag.account_id}:trail/${local.diag_trail_name}"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "diag" {
  name                          = local.diag_trail_name
  s3_bucket_name                = aws_s3_bucket.diag.id
  is_multi_region_trail         = false
  include_global_service_events = false

  # Object-level (data) events for the Elastic Beanstalk and CodePipeline buckets only.
  advanced_event_selector {
    name = "S3 objects in the Elastic Beanstalk and CodePipeline buckets"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field       = "resources.ARN"
      starts_with = ["arn:aws:s3:::elasticbeanstalk-", "arn:aws:s3:::codepipeline-"]
    }
  }

  depends_on = [aws_s3_bucket_policy.diag]
}
