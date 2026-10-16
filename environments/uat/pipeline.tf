module "client_portal_pipeline" {
  source = "../../modules/client-portal-pipeline"

  name              = "ClientPortal-UAT"
  github_repository = "Prestige-Inhome-Care/client-portal"
  branch            = "uat"

  # Existing connection to GitHub, shared with the other portals' pipelines.
  connection_arn = "arn:aws:codeconnections:ap-southeast-2:421089614203:connection/977bfeb1-6c7b-470c-ab55-b70939019ef1"

  eb_application_name      = module.client_portal.eb_application_name
  eb_environment_name      = module.client_portal.eb_environment_name
  eb_environment_id        = module.client_portal.eb_environment_id

  # TEMPORARY, now off: the missing piece was read access to the platform-assets bucket (added to the
  # narrow policy). Delete the broad policy code once the deployment is confirmed working without it.
  temporary_broad_deploy_policy = false

  # TEMPORARY: test whether the HTTPS-only rule on the artifact bucket is what blocks the deploy.
  enforce_tls_only = false
  eb_instance_role_name    = module.client_portal.instance_role_name
  eb_instance_profile_name = module.client_portal.instance_profile_name
}
