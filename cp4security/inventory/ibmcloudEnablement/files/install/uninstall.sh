#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

export chartsDir="$(cd $(dirname $0) && pwd)" 
export namespace=${JOB_NAMESPACE}
export cs_namespace="ibm-common-services"
export kubernetesCLI='oc'
export casePath="${chartsDir}/../../../.."


#===  FUNCTION  ================================================================
#   NAME: run
#   DESCRIPTION:  run a command to check for errors and exit if failed
#   PARAMETERS:
#       1: command to be executed
#       2: operation being executed, to aid error log output
# ===============================================================================
function run(){
  local cmd=$1
  local operation=$2
  if ! bash $cmd; then
    error_exit "$operation failed"
  fi

}

#===  FUNCTION  ================================================================
#   NAME: error_exit
#   DESCRIPTION:  function to exit with custom error message
#   PARAMETERS:
#       1: message to error to stdout
# ===============================================================================
error_exit() {
    echo >&2 "[ERROR] $1"
    exit 1
}

#===  FUNCTION  ================================================================
#   NAME: backup_pvc
#   DESCRIPTION:  Function to move backup pvc from CP4S namespace into kube-system to protect customer backup
# ===============================================================================
backup_pvc(){
    if ! oc get pvc cp4s-backup-pv-claim -n "${namespace}" 2>/dev/null;then
        echo "[INFO] cp4s-backup-pv-claim not found in ${namespace}, skipping backup of PVC into kube-system namespace"
        return
    fi 
    run "${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/resources/move_pvc.sh -fromnamespace ${namespace} -tonamespace kube-system cp4s-backup-pv-claim" "Backup of pvc cp4s-backup-pv-claim"
}

#===  FUNCTION  ================================================================
#   NAME: fetchCharts
#   DESCRIPTION:  download CP4S charts from public github for install
# ===============================================================================
function fetchCharts() {

  # foundations chart
  if ! wget -q https://github.com/IBM/charts/raw/master/repo/ibm-helm/ibm-security-foundations-prod-1.0.14.tgz -P "$chartsDir"; then error_exit "failed to download cp4s ibm-security-foundations-prod chart"; fi
  if ! tar -xvf "$chartsDir"/ibm-security-foundations-prod-1.0.14.tgz -C "${chartsDir}" >/dev/null 2>&1; then error_exit "failed to extract cp4s ibm-security-foundations-prod chart"; fi

  # solutions chart
  if ! wget -q https://github.com/IBM/charts/raw/master/repo/ibm-helm/ibm-security-solutions-prod-1.0.14.tgz -P "$chartsDir"; then error_exit "failed to download ibm-security-solutions-prod chart"; fi  
  if ! tar -xvf "$chartsDir"/ibm-security-solutions-prod-1.0.14.tgz -C "${chartsDir}" >/dev/null 2>&1; then error_exit "failed to extract cp4s ibm-security-solutions-prod chart"; fi
  
  cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-security-1.0.14.tgz --outputdir "${chartsDir}"/download_dir --tolerance 1 2>/dev/null
}

#===  FUNCTION  ================================================================
#   NAME: removeCS
#   DESCRIPTION:  removal of common services 3.4
# ===============================================================================
function removeCS() {
    echo "[INFO] removing common services"
    
    if [[ "X$ENVIRONMENT" == "XSTAGING" ]]; then
        registry="cp.stg.icr.io"
    else
        registry='cp.icr.io'
    fi

    if ! $kubernetesCLI get namespace ibm-common-services >/dev/null 2>&1; then
        echo "[INFO] common services deployment not found"
        return 0
    else
        run "${casePath}/inventory/installProduct/files/support/uninstall.sh -uninstall_cs catalog $registry" "Common Services uninstall"
        oc delete namespace "${namespace}" >/dev/null 2>&1
    fi
}

#===  FUNCTION  ================================================================
#   NAME: removeSolutions
#   DESCRIPTION:  removal of cp4s solutions release
# ===============================================================================
function removeSolutions() {
    local release_name="ibm-security-solutions"
    
    echo "[INFO] removing solutions release"
    oc project "$namespace"
    run "${casePath}/inventory/installProduct/files/support/uninstall.sh -uninstall_chart $release_name" "$release_name uninstall" 
}

#===  FUNCTION  ================================================================
#   NAME: removeFoundations
#   DESCRIPTION:  removal of cp4s foundations release
# ===============================================================================
function removeFoundations() {
    local release_name="ibm-security-foundations"
    echo "[INFO] removing foundations release"        
    run "${casePath}/inventory/installProduct/files/support/uninstall.sh -uninstall_chart $release_name" "$release_name uninstall"
}

#===  FUNCTION  ================================================================
#   NAME: uninstall_couchdb
#   DESCRIPTION:  removal of couchdb operator
# ===============================================================================
function uninstall_couchdb() {
    couch_case_dir="${chartsDir}/download_dir"
    run "${casePath}/inventory/installProduct/files/support/uninstall.sh -uninstall_couchdb $couch_case_dir" "couchdb operator uninstall"
}

#===  FUNCTION  ================================================================
#   NAME: uninstall_redis
#   DESCRIPTION:  removal of redis operator
# ===============================================================================
function uninstall_redis() {
    run "${casePath}/inventory/installProduct/files/support/uninstall.sh -uninstall_redis" "redis operator uninstall"
}

#===  FUNCTION  ================================================================
#   NAME: uninstall_operatorgroup
#   DESCRIPTION:  removal of redis operatorgroup
# ===============================================================================
function uninstall_operatorgroup(){
    run "${casePath}/inventory/installProduct/files/support/uninstall.sh -uninstall_operatorgroup" "Operator group uninstall"
}

#===  FUNCTION  ================================================================
#   NAME: fetchBinaries
#   DESCRIPTION:  fetch the uninstall required binaries
# ===============================================================================
function fetchBinaries() {
    # helm 3
    if ! wget --no-verbose -O /tmp/helm.tar.gz https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz; then
        error_exit "failure to pull helm3."
    fi
    
    if ! tar xvzf /tmp/helm.tar.gz; then
        error_exit "failure to extract helm3."
    fi
    chmod +x linux-amd64/helm
    mv linux-amd64/helm "$chartsDir"/helm3

    # download cloudctl
    if ! wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.4.1-1786/cloudctl-linux-amd64.tar.gz -O /tmp/cloudctl.tar.gz; then
        error_exit "failure to pull cloudctl"
    fi
    if ! tar xvfz /tmp/cloudctl.tar.gz; then
        error_exit "failure to extract cloudctl"
    fi
    chmod +x cloudctl-linux-amd64
    mv cloudctl-linux-amd64 "$chartsDir"/cloudctl

    # download oc
    if ! wget --no-check-certificate --no-verbose "https://downloads-openshift-console.${INGRESS_HOSTNAME}/amd64/linux/oc.tar"; then
        error_exit "failure to download oc"
    fi
    tar -xvf oc.tar
    chmod +x oc
    mv oc "$chartsDir"/oc  
    rm oc.tar

    # exposing binaries
    export PATH=$chartsDir:$PATH
    export helm3="$chartsDir"/helm3

    echo "[INFO] oc version check"
    oc version     
}

#Measure Progress
function measure_progress()
{  
    total_jobs=$1
    finished_jobs=$2
    remaining_jobs=$(( $total_jobs - $finished_jobs ))
    finish_percentage=$(( ($finished_jobs * 100) /$total_jobs ))
    remaining_percentage=$(( (($remaining_jobs * 100) /$total_jobs) + 2 ))
    h=$(printf '%0.s#' $(seq 1 ${finish_percentage}))
    d=$(printf '%0.s-' $(seq 1 ${remaining_percentage}) )
    echo "[Progress: ${h// /*}${d// /*} | Step $finished_jobs of $total_jobs, Task Completed: $stage_name]"
    printf "\n"
}
function status()
{
    exit_code=$1
    stage_name=$2
    total_stages=$3
    if [[ ${exit_code} == 0 ]]; then
        list1+=($stage_name)
    fi
    measure_progress $total_stages ${#list1[@]} $stage_name
}
# ====== MAIN ==========================
stages=("Validate-CP4S-PreReqs"  "Uninstall-Solutions" "Uninstall-Foundations" "Uninstall-Common-Services")
list1=()
fetchBinaries
fetchCharts
##check status
status $? Validate-CP4S-PreReqs ${#stages[@]}

backup_pvc
removeSolutions
##check status
status $? Uninstall-Solutions ${#stages[@]}
    
removeFoundations
uninstall_couchdb
uninstall_redis
uninstall_operatorgroup
##check status
status $? Uninstall-Foundations ${#stages[@]}

removeCS

##check status
status $? Uninstall-Common-Services ${#stages[@]}
