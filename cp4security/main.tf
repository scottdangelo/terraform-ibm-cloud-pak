locals {
  case                              = file(join("/", [path.module, "files", "case.yaml"])) 
  digest                            = file(join("/", [path.module, "files", "digest.yaml"])) 
  ibmccp                            = file(join("/", [path.module, "files", "ibmccp.yaml"])) 
  prereqs                           = file(join("/", [path.module, "files", "prereqs.yaml"])) 
  roles                             = file(join("/", [path.module, "files", "roles.yaml"])) 
  signature                         = file(join("/", [path.module, "files", "signature.yaml"]))
}

resource "null_resource" "install" {
  count = var.enable ? 1 : 0

  triggers = {
    force_to_run                              = var.force ? timestamp() : 0
    namespace_sha1                            = sha1(local.namespace)
    docker_params_sha1                        = sha1(join("", [var.entitled_registry_user_email, local.entitled_registry_key]))
    ibm_operator_catalog_sha1                 = sha1(local.ibm_operator_catalog)
    opencloud_operator_catalog_sha1           = sha1(local.opencloud_operator_catalog)
    services_subscription_sha1                = sha1(local.services_subscription)
    cp4a_subscription_sha1                    = sha1(local.cp4a_subscription)
    pvc_claim_sha1                            = sha1(local.pvc_claim)
    #security_context_constraints_content_sha1 = sha1(local.security_context_constraints_content)
    #installer_sensitive_data_sha1             = sha1(local.installer_sensitive_data)
    #installer_job_content_sha1                = sha1(local.installer_job_content)
  }

  provisioner "local-exec" {
    command     = "./install.sh"
    working_dir = "${path.module}/scripts"

    environment = {
      FORCE                         = var.force
      KUBECONFIG                    = var.cluster_config_path
      NAMESPACE                     = local.namespace
      IBM_OPERATOR_CATALOG          = local.ibm_operator_catalog
      OPENCLOUD_OPERATOR_CATALOG    = local.opencloud_operator_catalog
      SERVICES_SUBSCRIPTION         = local.services_subscription
      CP4A_SUBSCRIPTION             = local.cp4a_subscription
      PVC_CLAIM                     = local.pvc_claim
      DOCKER_REGISTRY_PASS          = local.entitled_registry_key
      DOCKER_USER_EMAIL             = var.entitled_registry_user_email
      DOCKER_USERNAME               = local.docker_username
      DOCKER_REGISTRY               = local.docker_registry
      #INSTALLER_SENSITIVE_DATA      = local.installer_sensitive_data
      #INSTALLER_JOB_CONTENT         = local.installer_job_content
      #SCC_ZENUID_CONTENT            = local.security_context_constraints_content
      // DEBUG                    = true
    }
  }
}
