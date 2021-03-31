#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020-2021. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

CS_NAMESPACE='ibm-common-services'
inventory="ibmCommonServiceOperatorSetup"
base_dir="$(cd $(dirname $0) && pwd)"
casePath="${base_dir}/../../../.."
kubernetesCLI="oc"
cp4s_namespace=""
airgapRepo="" # used for CASE airgap install only

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

exit_error() {
  echo "[ERROR] $1"
  exit 1
}

upgrade_cs() {

  catalog_source=""${casePath}"/inventory/"${inventory}"/files/op-olm/online_catalog_source.yaml"  
  namescope_file="${casePath}/inventory/${inventory}/files/op-olm/namespace_scope.yaml"

  # CS upgrade script
  versionCheck="ibm-common-service-operator.v3.6.3"
  checkInstall=$($kubernetesCLI get csv -n ${CS_NAMESPACE} | grep $versionCheck)
  if [ -n "$checkInstall" ]; then 
    echo "[INFO] Common Services 3.6.x is currently installed"
    exit 0
  fi

  maxRetry=10

  # Patch the operand request to add audit logging
  [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-olm/operand_request.yaml ]] && { exit_error "Missing required operand_request yaml, exiting deployment."; }
  oc apply -n ${CS_NAMESPACE} -f "${casePath}"/inventory/"${inventory}"/files/op-olm/operand_request.yaml

  ## check if doing airgap install to update image
  if [ "X$airgapRepo" != "X" ]; then
    sed <"${catalog_source}" "s|docker.io|${airgapRepo}|g"
  fi

  # Apply new catalog source
  oc apply -n openshift-marketplace -f ${catalog_source}
  sleep 10

  # Wait for catalog source pod to run
  for ((retry=0;retry<=${maxRetry};retry++)); 
  do
    echo "INFO - Waiting for catalog source pod initialisation"
    cs_pod=$(oc -n openshift-marketplace get pod -l olm.catalogSource=opencloud-operators --no-headers | awk '{print $2}' | grep '1/1')
    if [[ -z $cs_pod ]]; then
      if [[ $retry -eq ${maxRetry} ]]; then 
          exit_error "ERROR - Catalog source pod initialisation failed"
      else
          sleep 20
          continue
      fi
    else
        echo "INFO - Catalog source pod is running"
        break
    fi
  done  

  run "${casePath}/inventory/installProduct/files/support/validate.sh -cs" "Common Services Validation"
  
  for ((retry=0;retry<=${maxRetry};retry++));
  do
    nsscope_cr=$($kubernetesCLI get NamespaceScope common-service -n $CS_NAMESPACE --ignore-not-found=true)
    if [[ -z $nsscope_cr ]]; then
      if [[ $retry -eq ${maxRetry} ]]; then 
        exit_error "Namespace scope CR could not be found."
      else
        sleep 60
        continue
      fi
    else
      # update the namespace scope for granting ibm-common-services operator rights to manage CP4S namespace
      if ! sed <"$namescope_file" "s|REPLACE_NAMESPACE|$cp4s_namespace|g" | $kubernetesCLI apply -n "${CS_NAMESPACE}" -f -; then
        exit_error "common services namespace scope update failed"
      else
        echo "common services namespace scope updated"
        break
      fi
    fi
  done
  
  echo "INFO - Waiting for Common Services pods to be restarted after applying namespace scope CR"   
  
  # Additional slep to allow pods to initialise before the check
  sleep 60
  
  for ((retry=0;retry<=${maxRetry};retry++)); 
  do
    nonReady=$(oc get pod --no-headers -n $CS_NAMESPACE | grep -Ev "Running|Completed" | wc -l)
    if [[ $nonReady -ne 0 ]]; then
      if [[ $retry -eq ${maxRetry} ]]; then 
        exit_error " Error on Common Services Pods Startup."
      else
        sleep 60
        continue
      fi
    else
      echo "INFO - Common Services pods successfully restarted. Install of Common Services Completed."
      break
    fi
  done
}

while true
do
  arg="$1"
  if [ "X$1" == "X" ]; then
    break
  fi
  shift
  case $arg in
    -cp4sns)
      cp4s_namespace="$1"
      shift
      ;;
    -airgap)
      airgapRepo="$1"
      shift
      ;;
    *)
      echo "Invalid argument: $arg"
      usage
      exit 1
  esac
done

upgrade_cs
