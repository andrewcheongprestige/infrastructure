# Adopts the Partner Portal UAT pipeline, its role and policies, and the traffic path of the UAT site. An import block
# only records "this existing AWS resource is managed by this address". It changes nothing in AWS.
#
# The traffic path:
#   uat.partnerportal.prestigeinhomecare.com.au (DNS is outside AWS)
#   -> the certificate for that hostname (aws_acm_certificate.uat)
#   -> attached to the Admin Hub UAT load balancer's HTTPS listener (aws_lb_listener_certificate.uat)
#   -> the host rule on that listener, priority 10 (aws_lb_listener_rule.uat)
#   -> the target group PartnerPortal-UAT (aws_lb_target_group.uat)
#   -> the environment's instance.
#
# Left out on purpose:
#  - the Elastic Beanstalk environment and its Auto Scaling group registration (added after the secrets move to SSM,
#    because the environment's draft and plan would otherwise print its plain-text secrets),
#  - the application and the CodeBuild project (shared with Production, in stacks/partner-portal/shared),
#  - the load balancer and listener themselves (owned by the Admin Hub UAT environment, referenced by lookup),
#  - the Variphy rule and the other certificates on that listener (they belong to other applications).
#
# Workflow: terraform plan '-generate-config-out=generated.tf' (quote the argument in PowerShell), clean the draft
# into its own files, plan until the only differences are the intended ones, apply a saved plan.
# generated.tf is git-ignored on purpose and must never be committed.

import {
  to = aws_codepipeline.uat
  id = "PartnerPortalReactUAT"
}

import {
  to = aws_iam_role.pipeline
  id = "AWSCodePipelineServiceRole-ap-southeast-2-PartnerPortalReactUAT"
}

import {
  to = aws_iam_policy.pipeline_service
  id = "arn:aws:iam::421089614203:policy/service-role/AWSCodePipelineServiceRole-ap-southeast-2-PartnerPortalReactUAT"
}

import {
  to = aws_iam_policy.codebuild
  id = "arn:aws:iam::421089614203:policy/service-role/CodePipeline-CodeBuild-ap-southeast-2-PartnerPortalReactUAT"
}

import {
  to = aws_iam_policy.connection
  id = "arn:aws:iam::421089614203:policy/service-role/CodePipeline-CodeConnections-ap-southeast-2-PartnerPortalReactUAT"
}

import {
  to = aws_iam_role_policy_attachment.pipeline_service
  id = "AWSCodePipelineServiceRole-ap-southeast-2-PartnerPortalReactUAT/arn:aws:iam::421089614203:policy/service-role/AWSCodePipelineServiceRole-ap-southeast-2-PartnerPortalReactUAT"
}

import {
  to = aws_iam_role_policy_attachment.codebuild
  id = "AWSCodePipelineServiceRole-ap-southeast-2-PartnerPortalReactUAT/arn:aws:iam::421089614203:policy/service-role/CodePipeline-CodeBuild-ap-southeast-2-PartnerPortalReactUAT"
}

import {
  to = aws_iam_role_policy_attachment.connection
  id = "AWSCodePipelineServiceRole-ap-southeast-2-PartnerPortalReactUAT/arn:aws:iam::421089614203:policy/service-role/CodePipeline-CodeConnections-ap-southeast-2-PartnerPortalReactUAT"
}

import {
  to = aws_acm_certificate.uat
  id = "arn:aws:acm:ap-southeast-2:421089614203:certificate/07da3860-8cb7-4db1-83d5-23a907ed1390"
}

import {
  to = aws_lb_target_group.uat
  id = "arn:aws:elasticloadbalancing:ap-southeast-2:421089614203:targetgroup/PartnerPortal-UAT/ab259e517ad064bb"
}

import {
  to = aws_lb_listener_rule.uat
  id = "arn:aws:elasticloadbalancing:ap-southeast-2:421089614203:listener-rule/app/awseb--AWSEB-gTxOTz5Amz1n/9db83b12b0fd559a/379605735e2b3410/818c507066524fbd"
}

# The ID is the listener's ARN, an underscore, then the certificate's ARN.
import {
  to = aws_lb_listener_certificate.uat
  id = "arn:aws:elasticloadbalancing:ap-southeast-2:421089614203:listener/app/awseb--AWSEB-gTxOTz5Amz1n/9db83b12b0fd559a/379605735e2b3410_arn:aws:acm:ap-southeast-2:421089614203:certificate/07da3860-8cb7-4db1-83d5-23a907ed1390"
}
