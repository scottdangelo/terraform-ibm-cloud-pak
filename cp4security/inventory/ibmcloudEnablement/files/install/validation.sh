#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#===  CONSTANTS  ================================================================

export check=0
domain=${domain}
storageclass="${storageClass}"
ROKSDomain="${ROKSDomain}"
cert_file="${cert}"
key_file="${certKey}"
admin="${adminUserId}"

# validating adminUser
if [ -z "${admin}" ]; then
    echo "[ERROR] CP4S default admin user must be set"
    check=1
fi

# validating the domain
if [[ -n "${domain}" ]]; then
  if ! [[ ${domain} =~ ^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])(.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]))*$ ]]; then
    echo "[ERROR] the provided CP4S FQDN is invalid"
    check=1
  fi
  # validating certificates
  if [[ -z "${cert_file}" ]] || [[ -z "${key_file}" ]]; then
      echo "[ERROR] certificate and certificate key must be provided"
      check=1
  fi    
fi

# validating the storageclasses
if [ -z "${storageclass}" ]; then 
    echo "[ERROR] storageClass or fileStorageClass install params not set."
    check=1
fi

# check valid cp4s storageclass
main_storage=$(oc get sc | grep "$storageclass"| awk '{print $1;exit;}')

if [ "X$main_storage" == "X" ]; then
  available_storage=$(oc get sc | awk '{print $1}')
  echo "[ERROR] Storage class ($storageclass) was not found"
  echo "[ERROR] ################################"
  echo "[ERROR] Select from available storage"
  echo "###############################"
  echo "$available_storage"
  check=1
else 
   oc patch storageclass "$main_storage"  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
fi

# check default storageclas
dsc=""
for cl in $(kubectl get storageclass -o name)
do 
  def=$(kubectl get "$cl" -o jsonpath="{.metadata.annotations['storageclass\.kubernetes\.io/is-default-class']}")
  if [ "X$def" != "Xtrue" ]; then 
    continue
  fi
  if [ "X$dsc" != "X" ]; then
    echo "[ERROR] more than one default storage class: $dsc and $cl"
    check=1
  fi
  dsc="$cl"
done

if [ "X$dsc" == "X" ]; then
  echo "[ERROR] default storage class should be set"
  check=1
fi

if [ $check -ne 0 ]; then
  exit 1
fi