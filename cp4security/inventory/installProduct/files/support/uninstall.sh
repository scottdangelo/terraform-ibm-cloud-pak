#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************
export CS_NAMESPACE="ibm-common-services"
export TILLER_NAMESPACE="$CS_NAMESPACE"
# Remove foundations and solutions
function uninstall_charts(){

   release="$1"
   isInstalled=$(${helm3} ls --namespace "$namespace" | grep "$release" | awk '{print $1}')
   if [[ "$release" == "ibm-security-solutions" ]]; then
      
      echo "INFO - Uninstalling $release"

      if [[ "X$isInstalled" != "X" ]]; then
          if ! ${helm3} delete "$isInstalled" --namespace "$namespace" --timeout 800s; then 
            ${helm3} delete "$isInstalled" --namespace "$namespace" --no-hooks 
          fi
      else
          echo "WARNING - $release chart not found, proceeding with cleanup"
      fi
      echo "INFO - Cleaning up $release"
      if ! bash ${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-delete/Cleanup.sh -n "$namespace" --force --all --nowait >/dev/null 2>&1; 
      then 
        err "$release cleanup  completed with exceptions"
      else
          echo "INFO - $release cleanup complete"
      fi
    elif [[ "$release" == "ibm-security-foundations" ]]; then
         
         echo "INFO - Uninstalling $release"
         
         if [[ "X$isInstalled" != "X" ]]; then
            if ! ${helm3} delete "$isInstalled" --namespace "$namespace"; then
                ${helm3} delete "$isInstalled" --namespace "$namespace" --no-hooks
            fi
            echo "INFO - Cleaning up $release. NOTE: Rerun uninstall command if it takes more than 15mins to complete this stage"
            sleep 60
          else
             echo "WARNING - $release chart not found, proceeding with cleanup"
          fi
          if ! bash ${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/post-delete/Cleanup.sh -n "$namespace" --force --all >/dev/null 2>&1; then 
           err "$release cleanup  completed with exceptions"
          else
             echo "INFO - $release cleanup complete"
          fi       
    fi

}
## function to validate the required files are present
function validate_file_exists() {
    local file=$1
    [[ ! -f ${file} ]] && { err_exit "${file} not found, exiting deployment."; }
}

#===  FUNCTION  ================================================================
#   NAME: uninstall_couchdb
#   DESCRIPTION:  couchdb uninstall. Common for CASE and catalog
# ===============================================================================
function uninstall_couchdb() {
    
  local inventoryOfOperator="couchdbOperatorSetup"

  couch_case="${inputcasedir}/ibm-couchdb-1.0.8.tgz"
    
  if $kubernetesCLI get namespace $namespace >/dev/null 2>&1; then    
    
    if ! cloudctl case launch --case "$couch_case" --inventory $inventoryOfOperator --namespace "$namespace" --action uninstallCatalog --tolerance 1;
       then err_exit "Couchdb Operator Catalog uninstall has failed"
    fi

    echo "-------------Uninstalling subscription group-------------"
    
    if ! cloudctl case launch --case "$couch_case" --inventory $inventoryOfOperator --namespace "$namespace" --action uninstallOperator --tolerance 1;
      then err_exit "Couchdb Operator Operator uninstall has failed" 
    fi

  fi
  
  # remove objects that may be left behind
  local opgrp_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/operator_group.yaml
  $kubernetesCLI get serviceaccount -n "$namespace" --no-headers --ignore-not-found=true | awk '{print $1}' | grep couchdb-operator | xargs $kubernetesCLI delete serviceaccount -n "$namespace"
  $kubernetesCLI get deploy -n "$namespace" --no-headers --ignore-not-found=true | awk '{print $1}' | grep couchdb-operator | xargs $kubernetesCLI delete deploy -n "$namespace"
  $kubernetesCLI  get cm -n "$namespace" | grep couchdb | awk '{print $1}' |  xargs $kubernetesCLI delete cm -n "$namespace" --ignore-not-found=true
  $kubernetesCLI  get csv | grep couchdb-operator | awk '{print $1}' | xargs $kubernetesCLI delete csv --ignore-not-found=true
  $kubernetesCLI get installplan | grep couchdb-operator | awk '{print $1}' | xargs $kubernetesCLI delete installplan --ignore-not-found=true
}

## function to remove redis
function uninstall_redis() {
    #  local redis_case="${inputcasedir}/ibm-cloud-databases-redis-1.0.0.tgz"
    #  validate_file_exists $redis_case
    inventoryOfOperator="redisOperator"

    local catsrc_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/catalog_source.yaml
    local opgrp_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/operator_group.yaml
    local sub_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/subscription.yaml
    echo "-------------Uninstalling catalog source-------------"
    
    $kubernetesCLI delete -f "${catsrc_file}" --ignore-not-found=true
    
    echo "-------------Uninstalling subscription group-------------"
    $kubernetesCLI delete -f "${sub_file}" --ignore-not-found=true  

    # cloudctl case launch --case $redis_case --inventory redisOperator --namespace "$namespace" --action uninstallCatalog --tolerance 1 
    # # if [ $? -ne 0 ]; then err_exit "Redis Operator install has failed";fi
    # cloudctl case launch --case $redis_case --inventory redisOperator --namespace "$namespace" --action uninstallOperator --tolerance 1 
    # if [ $? -ne 0 ]; then err_exit "Redis Operator install has failed";fi
    #  ### remove objects that may be left behind
    ### remove serviceaccount
    $kubernetesCLI delete serviceaccount  ibm-cloud-databases-redis-operator-serviceaccount default-redis -n "$namespace" --ignore-not-found=true
    
    $kubernetesCLI get deploy -n "$namespace" --no-headers --ignore-not-found=true | awk '{print $1}' | grep "ibm-cloud-databases-redis-operator" | xargs $kubernetesCLI delete deploy -n "$namespace"
    ### delete key
    $kubernetesCLI delete secret ibm-entitlement-key -n "${namespace}" --ignore-not-found=true
    ## remove configmap
    $kubernetesCLI  get cm -n "$namespace" | grep redis | awk '{print $1}' |  xargs $kubernetesCLI delete cm -n "$namespace" --ignore-not-found=true
    ## remove csv
    $kubernetesCLI  get csv | grep ibm-cloud-databases-redis | awk '{print $1}' |  xargs $kubernetesCLI delete csv --ignore-not-found=true

    ## remove install plan
    $kubernetesCLI get installplan | grep ibm-cloud-databases-redis | awk '{print $1}' | xargs $kubernetesCLI delete installplan --ignore-not-found=true
}
function uninstall_generic_catalog (){
  inventoryOfOperator="InstallProduct"

  local catsrc_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/olm/catalog_source.yaml
  
  $kubernetesCLI delete -f "${catsrc_file}" --ignore-not-found=true

}
## function to remove operator group
function uninstall_operatorgroup(){

    inventoryOfOperator="redisOperator"
    local opgrp_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/operator_group.yaml

    echo "-------------Uninstalling operator group-------------"
    sed <"${opgrp_file}" "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI delete -n "$namespace" -f -  --ignore-not-found=true
}

## function to remove imagecontent source policy
function delete_sourcepolicy(){
  
  if [[ "X${airgapInstall}" != "X" ]]; then
    
    echo "INFO - Deleting image contentsourcepolicy"
    $kubernetesCLI delete imagecontentsourcepolicy ibm-cp-security --ignore-not-found=true
  fi
}

function del_crd(){
   crd="$1"
   ns="$CS_NAMESPACE"
   for cr in $($kubernetesCLI get $crd -o name 2>/dev/null)
   do
      $kubernetesCLI patch -n $ns $cr --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null
      $kubernetesCLI delete -n $ns $cr --wait=false 2>/dev/null
   done
   $kubernetesCLI patch crd $crd --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null
   $kubernetesCLI delete crd $crd --wait=false 2>/dev/null 
}

#===  FUNCTION  ================================================================
#   NAME: remove_rbF
#   DESCRIPTION:  remove iam rolebinding that may get stuck during uninstall
# ===============================================================================
remove_rbF() {
  role="$1"
  role_name="$2"
  ns="$3"

  obj=$(kubectl get "$role" "$role_name" -n "$ns" -o name 2>/dev/null)

  if [ "X$obj" == "X" ]; then
    return
  fi

  kubectl patch "$obj" --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
}

#===  FUNCTION  ================================================================
#   NAME: uninstall_cs
#   DESCRIPTION:  common services uninstall. Common for CASE and catalog
# ===============================================================================
function uninstall_cs(){

    if [[ "X$airgapInstall" != "X" ]] || [[ "X$uninstall_method" == "Xcatalog" ]]; then
        url="$repo"
    else
       url="docker.io"
    fi

    if ! cloudctl case launch --case "${casePath}" --namespace "$CS_NAMESPACE" --inventory ibmCommonServiceOperatorSetup --action uninstall-catalog --args "--registry $url" --tolerance 1; then 
     err_exit "Failed to install Common services catalog"
    fi

    if ! cloudctl case launch --case "${casePath}" --namespace "$CS_NAMESPACE" --inventory ibmCommonServiceOperatorSetup --action  uninstall-operator --tolerance 1; then 
     err_exit "Failed to install Common services operator"
    fi
    # deleting CRDs
    for crd in $($kubernetesCLI get crd --no-headers 2>/dev/null | grep "ibm.com" | awk '{print $1}')
    do
       del_crd "$crd"
    done
    $kubernetesCLI delete crd certificates.certmanager.k8s.io --ignore-not-found

    # CRD from CS 3.2.4 that may be left in the cluster
    $kubernetesCLI delete crd clusterissuers.certmanager.k8s.io --ignore-not-found
    $kubernetesCLI delete crd issuers.certmanager.k8s.io --ignore-not-found    

    $kubernetesCLI delete clusterrole ibm-helm-api-operand --ignore-not-found	
    $kubernetesCLI delete clusterrole ibm-platform-api-operand --ignore-not-found	
    $kubernetesCLI delete clusterrole ibm-helm-tiller-operand --ignore-not-found	
    $kubernetesCLI delete clusterrolebinding ibm-helm-api-operand --ignore-not-found	
    $kubernetesCLI delete clusterrolebinding ibm-platform-api-operand --ignore-not-found	
    $kubernetesCLI delete clusterrolebinding ibm-helm-tiller-operand --ignore-not-found	

    remove_rbF rolebindings.authorization.openshift.io admin "$namespace"    
 
}
function err_exit() {
    echo >&2 "[ERROR] $1"
    exit 1
}
function err() {
    echo >&2 "[ERROR] $1"
}

while true
do
  arg="$1"
  if [ "X$1" == "X" ]; then
    break
  fi
  shift
  case $arg in
    -uninstall_chart)
      chart="$1"
      shift
      uninstall_charts "$chart"
      ;;
    -uninstall_redis)
      uninstall_redis
      ;; 
    -uninstall_couchdb)
      inputcasedir="$1"
      shift    
      uninstall_couchdb
      ;; 
    -uninstall_cs)
      uninstall_method="$1"
      repo="$2"
      shift
      shift
      uninstall_cs
      ;;
    -uninstall_operatorgroup)
      uninstall_operatorgroup
      ;;
    -uninstall_generic_catalog)
      uninstall_generic_catalog
      ;;
    -contentsourcepolicy)
      delete_sourcepolicy
      ;;    
    *)
      echo "ERROR: Invalid argument: $arg"
      exit 1
      ;;
  esac
done
