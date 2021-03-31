#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020,2021. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************


cs_namespace="ibm-common-services"
kubernetesCLI="oc"
cp4s_namespace=""
repo=""

#===  FUNCTION  ================================================================
#   NAME: err_exit
#   DESCRIPTION:  function to exit with custom error message
#   PARAMETERS:
#       1: message to error to stdout
# ===============================================================================
err_exit() {
    echo >&2 "[ERROR] $1"
    exit 1
}

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
    err_exit "$operation failed"
  fi

}

csInstall() {

	scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	casePath="${scriptDir}/../../../.."  
  	inventoryOfOperator="ibmCommonServiceOperatorSetup"
  	online_catalog_source="${casePath}/inventory/${inventoryOfOperator}/files/op-olm/online_catalog_source.yaml"
	namescope_file="${casePath}/inventory/${inventoryOfOperator}/files/op-olm/namespace_scope.yaml"

	echo "[INFO] installing common services"   
	oc create namespace $cs_namespace  
	oc project $cs_namespace  
	
	if [[ "X$repo" != "X" ]]; then
		if ! cloudctl case launch --case "${casePath}" --namespace "$cs_namespace" --inventory "$inventoryOfOperator" --action install-catalog --args "--registry $repo" --tolerance 1 >/dev/null 2>&1; then 
			err_exit "Failed to install Common services catalog"
		fi    
	else
		if ! $kubernetesCLI apply -f $online_catalog_source; then 
		
			err_exit "Failed to install Common services catalog"
		fi
	fi


	if ! cloudctl case launch --case ${casePath} --namespace $cs_namespace --inventory ibmCommonServiceOperatorSetup --action install-operator --tolerance 1 >/dev/null 2>&1; then
		err_exit "Failed to install Common services operator"
	fi

	
	# update the namespace scope for granting ibm-common-services operator rights to manage CP4S namespace
	if ! sed <"$namescope_file" "s|REPLACE_NAMESPACE|$cp4s_namespace|g" | $kubernetesCLI apply -n "${cs_namespace}" -f -; then
		err_exit "common services namespace scope update failed"
	else
		echo "common services namespace scope updated"
	fi	

	run "${casePath}/inventory/installProduct/files/support/validate.sh -cs" "Common Services Validation"
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
      repo="$1"
	  shift
      ;;
    *)
      echo "Invalid argument: $arg"
      usage
      exit 1
  esac
done

csInstall