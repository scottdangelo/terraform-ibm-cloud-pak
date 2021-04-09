locals {
  case                              = file(join("/", [path.module, "files", "case.yaml"])) 
  digest                            = file(join("/", [path.module, "files", "digest.yaml"])) 
  ibmccp                            = file(join("/", [path.module, "files", "ibmccp.yaml"])) 
  prereqs                           = file(join("/", [path.module, "files", "prereqs.yaml"])) 
  roles                             = file(join("/", [path.module, "files", "roles.yaml"])) 
  signature                         = file(join("/", [path.module, "files", "signature.yaml"]))
  operatorgroup                     = file(join("/", [path.module, "inventory/couchdboperstorsetup/files", "operator_group.yaml"]))
  actions                           = file(join("/", [path.module, "inventory/couchdboperatorsetup", "actions.yaml"]))
  inventory                         = file(join("/", [path.module, "inventory/couchdboperatorsetup", "inventory.yaml"]))
  resources                         = file(join("/", [path.module, "inventory/couchdboperatorsetup", "resources.yaml"]))
  values-metadata                   = file(join("/", [path.module, "inventory/ibmcloudenablement/files", "values-metadata.yaml"]))
  valuesmetadata                    = file(join("/", [path.module, "inventory/ibmcloudenablement/files/install", "values-metadata.yaml"]))
  actions                           = file(join("/", [path.module, "inventory/ibmcloudenablement", "actions.yaml"]))
  inventory                         = file(join("/", [path.module, "inventory/ibmcloudenablement", "inventory.yaml"]))
  resources                         = file(join("/", [path.module, "inventory/ibmcloudenablement", "resourcs.yaml"]))
  commonservices                    = file(join("/", [path.module, "inventory/ibmcommonserviceoperatorsetup/files/op-olm", "common_service.yaml"]))
  namespace_score                   = file(join("/", [path.module, "inventory/imbcommonserviceoperatorsetup/files/op-olm", "namespace_scope.yaml"]))
  onlinecatalogsource               = file(join("/", [path.module, "inventory/imbcommonserviceoperatorsetup/files/op-olm", "online_catalog_source.yaml"]))
  operandrequest                    = file(join("/", [path.module, "inventory/imbcommonserviceoperatorsetup/files/op-olm", "operand_request.yaml"]))
  operator_group                    = file(join("/", [path.module, "inventory/imbcommonserviceoperatorsetup/files/op-olm", "operator_group.yaml"]))
  subscription                      = file(join("/", [path.module, "inventory/imbcommonserviceoperatorsetup/files/op-olm", "subscription.yaml"]))
  actions                           = file(join("/", [path.module. "inventory/ibmcommonserviceoperatorsetup", "actions.yaml"]))
  inventory                         = file(join("/", [path.module. "inventory/ibmcommonserviceoperatorsetup", "inventory.yaml"]))
  resources                         = file(join("/", [path.module. "inventory/ibmcommonserviceoperatorsetup", "resources.yaml"]))
  actions                           = file(join("/", [path.module. "inventory/ibmsecurityfoundations", "actions.yaml"]))
  inventory                         = file(join("/", [path.module. "inventory/ibmsecurityfoundations", "inventory.yaml"]))
  resources                         = file(join("/", [path.module. "inventory/ibmsecurityfoundations", "inventory.yaml"]))  
  actions                           = file(join("/", [path.module. "inventory/ibmsecuritysolutions", "actions.yaml"]))
  inventory                         = file(join("/", [path.module. "inventory/ibmsecuritysolutions", "inventory.yaml"]))
  resources                         = file(join("/", [path.module. "inventory/ibmsecuritysolutions", "resources.yaml"]))
  actions                           = file(join("/", [path.module. "inventory/ibmserviceability", "actions.yaml"]))
  inventory                         = file(join("/", [path.module. "inventory/ibmserviceability", "inventory.yaml"]))
  resources                         = file(join("/", [path.module. "inventory/ibmserviceability", "resources.yaml"]))
  connectorcr                       = file(join("/", [path.module. "inventory/installproduct/files/connectors", "connector-cr.yaml"]))
  catalog_source                    = file(join("/", [path.module. "inventory/installproduct/files/olm", "catalog_source.yaml"]))
  casesimages                       = file(join("/", [path.module. "inventory/installproduct/files", "cases_images.yaml"]))
  cases-cr                          = file(join("/", [path.module. "inventory/installproduct/files", "cases-cr.yaml"]))
  actions                           = file(join("/", [path.module. "inventory/installproduct", "actions.yaml"]))
  inventory                         = file(join("/", [path.module. "inventory/installproduct", "inventory.yaml"]))
  resources                         = file(join("/", [path.module. "inventory/installproduct", "inventory.yaml"]))
  catalogsource                     = file(join("/", [path.module. "inventory/redisoperator/files/op-olm", "catalog_source.yaml"]))
  operatorgroup                     = file(join("/", [path.module. "inventory/redisoperator/files/op-olm", "operator_group.yaml"]))
  subscription                      = file(join("/", [path.module. "inventory/redisoperator/files/op-olm", "subscription.yaml"]))
  actions                           = file(join("/", [path.module. "inventory/redisoperator", "actions.yaml"]))
  inventory                         = file(join("/", [path.module. "inventory/redisoperator", "inventory.yaml"]))
  resources                         = file(join("/", [path.module. "inventory/redisoperator", "resources.yaml"]))
  main                              = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.login/defaults", "main.yaml"]))
  main                              = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.login/defaults/tasks", "main.yaml"]))
  main                              = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.deploy/defaults", "main.yaml"]))
  openldap                          = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.deploy/files/openldap-chart/templates", "openldap.yaml"]))
  phpldapadmin                      = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.deploy/files/openldap-chart/templates", "phpldapadmin.yaml"]))
  chart                             = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.deploy/files/openldap-chart", "chart.yaml"]))
  image-policy                      = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.deploy/files", "image-policy.yaml"]))
  main                              = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.deploy/tasks", "main.yaml"]))
  values                            = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.deploy/templates", "values.yaml.j2"]))
  main                              = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.register/default", "main.yaml"]))
  main                              = file(join("/", [path.module. "scripts/ldap/roles/secops.icp.openldap.register/tasks", "main.yaml"]))
playbook                            = file(join("/", [path.module. "scripts/ldap", "playbook.yaml"]))

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
