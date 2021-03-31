#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020,2021. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#===  FUNCTION  ================================================================
#   NAME: error_exit
#   DESCRIPTION:  function to exit with custom error message
#   PARAMETERS:
#       1: message to error to stdout
# ===============================================================================
function error_exit() {
    echo >&2 "[ERROR] $1"
    exit 1
}

#===  FUNCTION  ================================================================
#   NAME: validate_file_exists
#   DESCRIPTION:  validate if a path given contains a valid file
#   PARAMETERS:
#       1: filepath
# ===============================================================================
function validate_file_exists() {
  local file=$1
  [[ ! -f ${file} ]] && { error_exit "${file} not found, exiting deployment."; }
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
    error_exit "$operation failed"
  fi

}

#===  FUNCTION  ================================================================
#   NAME: setEntitlementSecret
#   DESCRIPTION:  set the entitlement key secret
# ===============================================================================
function setEntitlementSecret() {
  local entitlementUser="$DOCKER_REGISTRY_USER"
  local entitlementKey="$DOCKER_REGISTRY_PASS"
  local entitlementRepo="cp.icr.io"

  sc=$(kubectl get secret -n "$NAMESPACE" ibm-entitlement-key 2>/dev/null)
  if [ "X$sc" != "X" ]; then
     kubectl delete secret -n "$NAMESPACE" ibm-entitlement-key
  fi
  
  if ! kubectl create secret docker-registry ibm-entitlement-key -n "$NAMESPACE" \
  --docker-server="$entitlementRepo" "--docker-username=${entitlementUser}" \
  "--docker-password=${entitlementKey}";
  then error_exit "secret ibm-entitlement-key creation"
  fi
  
}

#===  FUNCTION  ================================================================
#   NAME: backup_pvc
#   DESCRIPTION:  Function to move backup pvc from kube-system to CP4S namespace when existing
# ===============================================================================
backup_pvc(){
  if ! oc get pvc cp4s-backup-pv-claim -n kube-system 2>/dev/null;then
    echo "[INFO] cp4s-backup-pv-claim not found in kube-system, skipping restore of pvc into namespace ${NAMESPACE}"
    return
  fi 
  run "${base_dir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/resources/move_pvc.sh -fromnamespace kube-system -tonamespace ${NAMESPACE} cp4s-backup-pv-claim" "Restore of pvc cp4s-backup-pv-claim"
}

#===  FUNCTION  ================================================================
#   NAME: check_sequence
#   DESCRIPTION:  get the status of a particular iscsequence
#   PARAMETERS:
#       1: sequence to be checked
# ===============================================================================
function check_sequence() {
  local seq=$1
  sequence_status=$(oc get iscsequence $seq -n $NAMESPACE 2>/dev/null | awk 'FNR == 2 {print $2}')

  # avoid deadlock if sequence gets deleted during check_sequence()
  if [ "X$sequence_status" == "X" ]; then return; fi 

  guard_id=$(kubectl get iscguard $seq -o 'jsonpath={.spec.generation}' 2>/dev/null)
  seq_id=$(kubectl get iscsequence $seq -o 'jsonpath={.spec.labels.generation}' 2>/dev/null)  

  until [[ "X$guard_id" == "X$seq_id" || $sequence_status =~ "Failed" ]]
  do
    sequence_status=$(oc get iscsequence $seq -n $NAMESPACE | awk 'FNR == 2 {print $2}')
    guard_id=$(kubectl get iscguard $seq -o 'jsonpath={.spec.generation}' 2>/dev/null)
    running_sequence=$(oc get iscsequence -n $NAMESPACE | grep Running | awk '{print $1}')
    echo "INFO - $running_sequence sequence is running"
    sleep 90
  done
  if [[ "X$guard_id" == "X$seq_id" ]]; then
      successful_seq+=("$seq")
      echo "INFO - $seq status is $sequence_status"
  elif [[ $sequence_status == *"Failed"* ]]; then
      echo "INFO - $seq status is $sequence_status"
      failed_seq+=("$seq")
  fi
}

#===  FUNCTION  ================================================================
#   NAME: install_status
#   DESCRIPTION:  get the status of the release
#   PARAMETERS:
#       1: release to be checked
# ===============================================================================
function install_status(){
  local chart=$1
  local maxRetry=15
  local to_retry

    if [[ $chart == "ibm-security-foundations" ]]; then
      local release_name=$(helm3 ls --namespace $NAMESPACE | grep $chart | awk '{print $1}')
      for ((retry=0;retry<=maxRetry;retry++));
      do
        statuses=$(kubectl get pod --no-headers -n "$NAMESPACE" -lrelease="$release_name" | awk '{print $3}')
        for status in ${statuses[@]};
        do
          if [[ $status != "Running" ]]; then
              if [ $retry -eq $maxRetry ]; then error_exit "one or more $foundations_release_name pods are on NotRunning state"; fi
              echo "[INFO] waiting for foundations pod to run" 
              sleep 60
              continue
          else
            break
          fi
        done        
        echo "[INFO] $foundations_release_name pods running"        
      done
    else
      successful_seq=()
      failed_seq=()

      echo "INFO - Install Status of ibm-security-solutions"
      sequence_list=$(oc get iscsequence -n $NAMESPACE --no-headers | awk '{print $1}' | sort)
      
      # check the status of all sequence
      for seq in ${sequence_list[@]}
      do
        check_sequence "$seq"
      done
      
      # retry failed sequences
      to_retry=("${failed_seq[@]}")
      failed_seq=()
      for seq in ${to_retry[@]}; do 
        sequence_status=$(oc get iscsequence $seq -n $NAMESPACE | awk 'FNR == 2 {print $2}')
        if [[ ! $sequence_status == *"Successful"* ]]; then  
          echo "[INFO] retrying sequence $seq"    
          bash "${base_dir}"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/runseq.sh "$seq"
          check_sequence "$seq"
        fi        
      done

      # Check status of cases
      cases_pods=$(oc get pod -n "$NAMESPACE" --no-headers | grep cases | awk '{print $1}')
      for pod in ${cases_pods[@]}
      do
        cases_pods_status=$(oc get pod $pod -n "$NAMESPACE" | awk 'FNR == 2 {print $3}')
        if [[ $cases_pods_status =~ "Running" || $cases_pods_status =~ "Completed" ]]; then
            echo "INFO - $pod pod is $cases_pods_status"
        else
            echo "INFO - $pod  pod status is $cases_pods_status"
       fi
      done
      ### Double check sequence
      if [[ -n ${failed_seq[*]} ]]; then 
          latest_failed_seq=()
          for i in ${failed_seq[*]}; do
            latest_status=$(oc get iscsequence "$i" -n "$NAMESPACE" | awk 'FNR == 2 {print $2}')
            if [[ $latest_status == *"Failed"*  ]]; then
              latest_failed_seq+=("$i")
            fi
          done
      fi
              
      checkcr=$(bash ${base_dir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/checkcr.sh -n $NAMESPACE --all)

      if [[ $checkcr =~ "Failed" ]] || [[ $checkcr == *"non-running"* ]]; then
         if [[ -z "${latest_failed_seq[@]}" ]]; then
            echo "[WARNING] All sequence finished Sucessfully but problems with crs. $checkcr"
          else
            echo "[ERROR] Problem with $chart installation"
            echo "[ERROR] The following sequence have failed: ${latest_failed_seq[@]}"
            error_exit "$checkcr"
          fi
      else
          if [[ -z "${latest_failed_seq[@]}" ]]; then
              echo "[INFO] All sequence finished Sucessfully"
          else
            echo "[ERROR] Problem with $CHART installation"
            echo "[ERROR] following sequence have failed: ${latest_failed_seq[@]}"
            error_exit "$checkcr"
          fi
      fi
      if [[ -z "${latest_failed_seq[@]}" ]]; then
          echo "INFO - All sequence finished."
      else
          echo "[ERROR] Problem with $chart installation"
          error_exit "$checkcr"
      fi    
    fi
  }

#===  FUNCTION  ================================================================
#   NAME: chart_prereq
#   DESCRIPTION:  execute the prereqcheck and fail if not successful
# ===============================================================================
function chart_prereq(){
    local chart=$1
    local maxRetry=4

    if [[ $chart == "ibm-security-solutions" ]]; then
       flag="--solutions"
    fi

    for ((retry=0;retry<maxRetry;retry++)); do
      echo "[INFO] running prerequesite checks for $chart"
      if bash "$base_dir"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/checkprereq.sh -n "$NAMESPACE" $flag; then
        return 0
      fi
      sleep 60
    done

    error_exit "$chart prereq check has failed"	 
}

#===  FUNCTION  ================================================================
#   NAME: fetchBinaries
#   DESCRIPTION:  fetch the install required binaries
# ===============================================================================
function fetchBinaries() {
  # download helm3
  if ! wget --no-verbose -O /tmp/helm.tar.gz https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz; then
    error_exit "failure to download helm3"
  fi
  tar xvzf /tmp/helm.tar.gz
  chmod +x linux-amd64/helm
  mv linux-amd64/helm "$base_dir"/helm3

  # download helm2
  if ! wget --no-verbose -O /tmp/helm.tar.gz https://get.helm.sh/helm-v2.12.3-linux-amd64.tar.gz; then
    error_exit "failure to download helm2"
  fi
  tar xvzf /tmp/helm.tar.gz
  chmod +x linux-amd64/helm
  mv linux-amd64/helm "$base_dir"/helm
  helm2="$base_dir/helm" 

  # download cloudctl
  if ! wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.4.1-1786/cloudctl-linux-amd64.tar.gz -O /tmp/cloudctl.tar.gz; then
    error_exit "failure to download cloudctl"
  fi
  tar xvfz /tmp/cloudctl.tar.gz
  chmod +x cloudctl-linux-amd64 
  mv cloudctl-linux-amd64 "$base_dir"/cloudctl

  # download oc
  if ! wget --no-check-certificate --no-verbose "https://downloads-openshift-console.${INGRESS_HOSTNAME}/amd64/linux/oc.tar"; then
    error_exit "failure to download oc"
  fi
  tar -xvf oc.tar
  chmod +x oc
  mv oc "$base_dir"/oc  
  rm oc.tar

  # exposing binaries
  export PATH=$base_dir:$PATH
  export helm3="$base_dir/helm3"  

  echo "[INFO] oc version check"
  oc version 
}

#===  FUNCTION  ================================================================
#   NAME: csLogin
#   DESCRIPTION:  login on common services
# ===============================================================================
function csLogin() {
  export TILLER_NAMESPACE=$cs_namespace
  local maxRetry=5

  cs_host=$(oc get route --no-headers -n "$cs_namespace" | grep "cp-console" | awk '{print $2}')

  if [[ -z $cs_host ]]; then
    for ((retry=0;retry<=${maxRetry};retry++)); 
      do
        oc delete pod -l name=ibm-management-ingress-operator -n $cs_namespace
        echo "INFO - Waiting for Management Ingress and Common Web UI pods to start running"
        oc wait --for=condition=Ready pod -l name=ibm-management-ingress-operator -n $cs_namespace --timeout=60s >/dev/null 2>&1
        oc wait --for=condition=Ready pod -l app.kubernetes.io/name=common-web-ui -n $cs_namespace --timeout=120s >/dev/null 2>&1
        oc wait --for=condition=Ready pod -l app.kubernetes.io/name=management-ingress -n $cs_namespace --timeout=60s >/dev/null 2>&1
        cs_host=$(oc get route --no-headers -n "$cs_namespace" | grep "cp-console" | awk '{print $2}')
        if [[ -z $cs_host ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then 
                error_exit "Failed to retrieve Common Services cp-console route"
            else
                sleep 60
                continue
            fi
        else
            break
        fi
      done
    fi

  cs_pass=$(oc -n "$cs_namespace" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode)
  cs_user=$(oc -n "$cs_namespace" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode)

  if ! cloudctl login -a "$cs_host" -u "$cs_user" -p "$cs_pass" -n "$NAMESPACE" --skip-ssl-validation; then
    error_exit "failure on common services login"
  fi
}

#===  FUNCTION  ================================================================
#   NAME: fetchCharts
#   DESCRIPTION:  download CP4S charts from public github for install
# ===============================================================================
function fetchCharts() {

  # foundations chart
  if ! wget -q https://github.com/IBM/charts/raw/master/repo/ibm-helm/ibm-security-foundations-prod-1.0.14.tgz; then error_exit "failed to download cp4s ibm-security-foundations-prod chart"; fi
  if ! tar -xvf ibm-security-foundations-prod-1.0.14.tgz -C "$base_dir" >/dev/null 2>&1; then error_exit "failed to extract cp4s ibm-security-foundations-prod chart"; fi

  # solutions chart
  if ! wget -q https://github.com/IBM/charts/raw/master/repo/ibm-helm/ibm-security-solutions-prod-1.0.14.tgz; then error_exit "failed to download ibm-security-solutions-prod chart"; fi
  if ! tar -xvf ibm-security-solutions-prod-1.0.14.tgz -C "$base_dir" >/dev/null 2>&1; then error_exit "failed to extract cp4s ibm-security-solutions-prod chart"; fi
  
  cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-security-1.0.14.tgz --outputdir "$base_dir"/download_dir --tolerance 1 2>/dev/null
}

#===  FUNCTION  ================================================================
#   NAME:restart_community_operators
#   DESCRIPTION:  Restart the certified and community operator pods
# ===============================================================================
## Temporary workaround to restart certified and community operators to have latest of couchdboperator
restart_community_operators(){
    local maxRetry=6
    echo "INFO - Restarting certified and community operator pod "
    regx="4.6.[0-9]*"
    oc_version=$(oc version | grep "Server Version:")
    if [[ $oc_version =~ $regx ]]; then
        cert_filter="-lolm.catalogSource=certified-operators"
        comm_filter="-lolm.catalogSource=community-operators"
    else
        cert_filter="-lmarketplace.operatorSource=certified-operators"
        comm_filter="-lmarketplace.operatorSource=community-operators"
    fi
    cert_op=$(oc get pod $cert_filter -n openshift-marketplace --no-headers 2>/dev/null)
    comm_op=$(oc get pod $comm_filter -n openshift-marketplace --no-headers 2>/dev/null)
    if [[ "X$cert_op" != "X" ]]; then
      if ! oc delete pod $cert_filter -n openshift-marketplace 2>/dev/null; then
        echo "[ERROR] Failed to restart certified-operators pod"
      fi
    fi
    if [[ "X$comm_op" != "X" ]]; then
      if ! oc delete pod $comm_filter  -n openshift-marketplace 2>/dev/null; then
        echo "[ERROR] Failed to restart community-operators pod"
      fi 
    fi

    for ((retry=0;retry<=${maxRetry};retry++)); do   
    
    echo "INFO - Waiting for Community and certified operators pod initialization"         
    
    iscertReady=$(oc get pod $cert_filter -n openshift-marketplace --no-headers 2>/dev/null | awk '{print $3}' | grep "Running")
    iscommReady=$(oc get pod $comm_filter -n openshift-marketplace --no-headers 2>/dev/null | awk '{print $3}' | grep "Running")
    if [[ "${iscertReady}${iscommReady}" != "RunningRunning" ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
           error_exit "Timeout Waiting for certified-operators and community operators to start"
        else
          sleep 30
          continue
        fi
    else
        echo "INFO - certified-operators and community operators are running"
        break
    fi
    done


}

#===  FUNCTION  ================================================================
#   NAME: install_couchdb
#   DESCRIPTION:  install couchdb based on the case inventory
# ===============================================================================
function install_couchdb() {
    local inventoryOfOperator="couchdbOperatorSetup"
    local online_source="certified-operators"
    local sub="couchdb-operator-catalog-subscription"
    local couch_case="${base_dir}/download_dir/ibm-couchdb-1.0.8.tgz"
    local channelName="v1.4"
    local maxRetry=20
    validate_file_exists "${casepath}"/inventory/"${inventoryOfOperator}"/files/operator_group.yaml
    validate_file_exists "$couch_case"

    echo "Checking if CouchDB Operator is already installed"

    CURRENT_COUCHDB_VERSION=$(oc get csv -n $NAMESPACE | grep couchdb | awk '{print $6;}') 

    if [[ "${CURRENT_COUCHDB_VERSION}" == [1-9].[4-9].[1-9] ]]; then
        echo "CouchDB Operator $CURRENT_COUCHDB_VERSION is already installed"
    else 

      echo "-------------Installing couchDB operator via OLM-------------"
      if [[ $(oc get og -n "${NAMESPACE}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
        echo "Found operator group"
        oc get og -n "${NAMESPACE}" -o yaml
      else
        sed <"${casepath}"/inventory/"${inventoryOfOperator}"/files/operator_group.yaml "s|REPLACE_NAMESPACE|${NAMESPACE}|g" | oc apply -n "${NAMESPACE}" -f -
        if [ $? -eq 0 ]
        then
          echo "CP4S Operator Group Created"
        else
          error_exit "CP4S Operator Group creation failed"
        fi
      fi
        
      if ! cloudctl case launch --case "$couch_case" --inventory couchdbOperatorSetup --namespace "${NAMESPACE}" --action installOperator --args "--catalogSource $online_source --channelName $channelName" --tolerance 1; then 
        error_exit "Couchdb Operator install has failed";
      fi

   
      for ((retry=0;retry<=${maxRetry};retry++)); do
        
        echo "[INFO] Waiting for Couchdb operator pod initialization"         
       
        isReady=$(oc get pod -n "$NAMESPACE" -lname=couchdb-operator --no-headers | grep "Running")
        if [[ -z $isReady ]]; then
          if [[ $retry -eq ${maxRetry} ]]; then 
            error_exit "Timeout Waiting for couchdboperator to start"
          else
            sleep 30
            continue
          fi
        else
          echo "[INFO] Couchdb operator is running $isReady"
          break
        fi    
      done
    fi  
}

#===  FUNCTION  ================================================================
#   NAME: install_redis
#   DESCRIPTION:  install redis based on the case inventory
# ===============================================================================
function install_redis() {
    local inventoryOfOperator="redisOperator"
    local inventoryOfcatalog="installProduct"
    local online_source="ibm-operator-catalog"
    local sub="ibm-cloud-databases-redis-operator-subscription"
    # local redis_case="${base_dir}/download_dir/ibm-cloud-databases-redis-1.1.3.tgz"
    local maxRetry=20

    local generic_catalog_source="${casepath}"/inventory/"${inventoryOfcatalog}"/files/olm/catalog_source.yaml
    local operator_group="${casepath}"/inventory/"${inventoryOfOperator}"/files/op-olm/operator_group.yaml
    local subscription="${casepath}"/inventory/"${inventoryOfOperator}"/files/op-olm/subscription.yaml
    
    validate_file_exists "$generic_catalog_source"
    validate_file_exists "$operator_group"
    validate_file_exists "$subscription"


    echo "Checking if Redis Operator is already installed"

    CURRENT_REDIS_VERSION=$(oc get csv -n $NAMESPACE | grep redis | awk '{print $6;}') 

    if [[ "${CURRENT_REDIS_VERSION}" == [1-9].[0-9].[0-9] ]]; then
      echo "Redis Operator $CURRENT_REDIS_VERSION is already installed"
    else 
      echo "Installing Redis Operator"
      # validate_file_exists $redis_case
      # local isPresent=$(oc get sub "$sub" -n "${NAMESPACE}"  --no-headers | awk '{print $4}' 2>/dev/null)
      # if [[ $isPresent == "v1.0" ]]; then
             
      #     if ! oc delete sub "$sub" -n "${NAMESPACE}"; then

      #        error_exit "Failed to delete old redisoperator subscription"
      #     fi
      # fi
    
      # echo "-------------Installing Redis operator via OLM-------------"
    
      # if oc get catalogsource -n openshift-marketplace | grep ibm-operator-catalog; then
      #     echo "Found ibm operator catalog source"
        
      # else
      #     if ! oc apply -f "$generic_catalog_source" ; then
      #         error_exit "Generic Operator catalog source creation failed"
      #     fi
      #     echo "ibm operator catalog source created"

      # fi
      #   if ! cloudctl case launch --case "$redis_case" --inventory redisOperator --namespace "${NAMESPACE}" --action installOperator --args "--catalogSource $online_source" --tolerance 1; then 
      #   error_exit "Redis Operator install has failed";
      # fi

      # echo "-------------Installing Redis operator via OLM-------------"
    
      if oc get catalogsource -n openshift-marketplace | grep ibm-operator-catalog; then
        echo "Found ibm operator catalog source"
        
      else
        if ! oc apply -f "$generic_catalog_source" ; then
            error_exit "Generic Operator catalog source creation failed"
        fi
        echo "ibm operator catalog source created"

      fi
      if [[ $(oc get og -n "${NAMESPACE}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
        echo "Found operator group"
        oc get og -n "${NAMESPACE}" -o yaml
      else
        sed <"${casepath}"/inventory/"${inventoryOfOperator}"/files/op-olm/operator_group.yaml "s|REPLACE_NAMESPACE|${NAMESPACE}|g" | oc apply -n "${NAMESPACE}" -f -
        if [ $? -eq 0 ]
        then
          echo "CP4S Operator Group Created"
        else
          error_exit "CP4S Operator Operator Group creation failed"
        fi
      fi

      sed <"${casepath}"/inventory/"${inventoryOfOperator}"/files/op-olm/subscription.yaml "s|REPLACE_NAMESPACE|${NAMESPACE}|g; s|REPLACE_SOURCE|$online_source|g" | oc apply -n "${NAMESPACE}" -f -
      if [ $? -eq 0 ]
        then
        echo "Redis Operator Subscription Created"
      else
        error_exit "Redis Operator Subscription creation failed"
      fi

      for ((retry=0;retry<=${maxRetry};retry++)); do        
        echo "INFO - Waiting for Redis operator pod initialization"         
       
        isReady=$(oc get pod -n "$NAMESPACE" -lname=ibm-cloud-databases-redis-operator --no-headers | grep "Running")
        if [[ -z $isReady ]]; then
          if [[ $retry -eq ${maxRetry} ]]; then 
            error_exit "Timeout Waiting for Redis operator to start"
          else
            sleep 30
            continue
          fi
        else
          echo "[INFO] Redis operator is running $isReady"
          break
        fi
      done 
    fi   
}

#===  FUNCTION  ================================================================
#   NAME: set_domain
#   DESCRIPTION: discover domain when not set
#   PARAMETERS:
# ===============================================================================
set_domain() {
   if [ ! -z "${domain}" ]; then
     return
   fi

   domain="cp4s.$(oc get -n openshift-console route console -o jsonpath="{.spec.host}" | sed -e 's/^[^\.]*\.//')"
   if [ "$domain" == "cp4s." ]; then
      error_exit "Failed to discover domain"
   fi
}

#===  FUNCTION  ================================================================
#   NAME: convert_cert
#   DESCRIPTION:  convert cert to file
#   PARAMETERS:
#       1: file_name
#       2: file_data
# ===============================================================================
function convert_cert(){
    file_name="$1"
    file_data="$2"
    printf "%s" "${file_data}" > ${file_name}
    sed -i 's/\\n/\n/g' ${file_name}
    sed -i 's/\"//g' ${file_name}
}

#===  FUNCTION  ================================================================
#   NAME: process_certs
#   DESCRIPTION:  process_certs
#   PARAMETERS:
# ===============================================================================
function process_certs(){
    if [ ! -z "${domain}" ]; then
        convert_cert "./cert.crt" "${cert_file}"
        convert_cert "./cert.key" "${key_file}"
        
        if [ -z "$custom_ca" ]; then
              echo "[INFO] install with trusted cert"
              run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n $NAMESPACE -key cert.key -cert cert.crt -force -resources" "solutions pre-install"
        else
           convert_cert "./ca.crt" "${custom_ca}"
           echo "[INFO] install with custom ca"
           run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n $NAMESPACE -key cert.key -cert cert.crt -ca ./ca.crt -force -resources" "solutions pre-install"
        fi
    else
           echo "[INFO] install with cluster certificate"
           run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n $NAMESPACE -roks -force -resources" "solutions pre-install"    
    fi
        
}

#===  FUNCTION  ================================================================
#   NAME: postinstall_solutions
#   DESCRIPTION:  post-install solutions release for ROKS
# ===============================================================================
postinstall_solutions() {
    if [ "X$OpenshiftAuthentication" == "XDisable" ]; then
      return
    fi
   
    echo "[INFO] post install for ROKS environment"
    run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-install/postInstall.sh -n $NAMESPACE -roks"
}

#===  FUNCTION  ================================================================
#   NAME: install_chart
#   DESCRIPTION:  install foundations or solutions release
#   PARAMETERS:
#       1: release to be installed
# ===============================================================================
function install_chart(){
    local chart=$1
    CP4S_VERSION="$( cat $casepath/case.yaml  | grep appVersion | awk '{print $2;}' | sed -r 's/"//g' | sed -r 's/-/./g' )"
    if [[ $chart == "ibm-security-foundations" ]]; then
      echo "Checking if Foundations $CP4S_VERSION is already installed"

      CURRENT_FOUNDATIONS_VERSION=$(helm3 ls --namespace $NAMESPACE | grep foundations | awk '{print $10;}') 

      if [[ "${CURRENT_FOUNDATIONS_VERSION}" == "${CP4S_VERSION}" ]]; then
        echo "Foundations $CP4S_VERSION is already installed"
      else 
        echo "[INFO] installing CP4S foundations chart"
        repo_secret=$(echo $REPOSITORY | sed "s/\/cp\/cp4s//") # pull secret at the root of the repo
        run "$base_dir/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n $NAMESPACE -repo $repo_secret $DOCKER_REGISTRY_USER $DOCKER_REGISTRY_PASS -force" "foundations pre-install" 
        chart_prereq "$chart" # checking foundations pre-install prerequisites.
        if ! helm3 upgrade --install "$chart" --namespace="${NAMESPACE}" --set global.repositoryType="${repository_type}" --set global.repository="${REPOSITORY}" --set global.helmUser="${cs_user}" --values "$base_dir"/ibm-security-foundations-prod/values.yaml --set global.license="accept" --set global.cloudType="ibmcloud" --set global.imagePullPolicy="${pullPolicy}" "$base_dir"/ibm-security-foundations-prod --timeout 1000s; then
          error_exit "foundations installation failed"
        fi
        sleep 60
      fi
    else
      echo "Checking if Solutions $CP4S_VERSION is already installed"

      CURRENT_SOLUTIONS_VERSION=$(helm3 ls --namespace $NAMESPACE | grep solutions | awk '{print $10;}') 

      if [[ "${CURRENT_SOLUTIONS_VERSION}" == "${CP4S_VERSION}" ]]; then
        echo "Solutions $CP4S_VERSION is already installed"
      else 
        echo "[INFO] installing CP4S solutions chart"
        process_certs
        set_domain
        extraArgs=""
        if [ "X$OpenshiftAuthentication" == "XEnable" ]; then
          extraArgs=",global.roks=true"
        fi
      
        chart_prereq "$chart" # checking solutions pre-install prerequisites.
        if ! helm3 upgrade --install "$chart" --namespace="${NAMESPACE}" --set global.repositoryType="${repository_type}",global.repository="${REPOSITORY}",global.cluster.icphostname="$cs_host",global.storageClass="$storageclass",global.domain.default.domain="${domain}",global.cluster.hostname="${INGRESS_HOSTNAME}",global.csNamespace="$cs_namespace",global.adminUserId="${default_admin_user}",global.imagePullPolicy="${pullPolicy}""$setExtraValues$extraArgs" --values "$base_dir"/ibm-security-solutions-prod/values.yaml "$base_dir"/ibm-security-solutions-prod --timeout 1000s; then
          error_exit "solutions installation failed"
        fi
      
        sleep 60
      fi
    fi
  }

#===  FUNCTION  ================================================================
#   NAME: upgrade_charts
#   DESCRIPTION:  upgrade the release from 1.5.0.0 to 1.6.0.0
#   PARAMETERS:
#       1: release to be upgraded
# ===============================================================================
function upgrade_charts() {
  local chart=$1
  echo "[INFO] upgrading $chart release"
  if [[ $chart == "ibm-security-foundations" ]]; then
    foundations_release=$(helm3 ls --namespace "$NAMESPACE" | grep "$foundations_release_name" | awk '{print $1;exit;}')
    chart_prereq "$chart" # checking foundations pre-install prerequisites.    
    run "$base_dir/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-upgrade/preUpgrade.sh -n $NAMESPACE -helm2 $helm2" "$foundations_release_name pre-upgrade"
    if ! helm3 upgrade --install "$foundations_release" --namespace="$NAMESPACE" --set global.repositoryType="$repository_type" --set global.repository="$REPOSITORY" --set global.license="accept" --set global.cloudType="ibmcloud" --set global.helmUser="$cs_user" --set global.imagePullPolicy="${pullPolicy}" --values "$base_dir"/ibm-security-foundations-prod/values.yaml "$base_dir"/ibm-security-foundations-prod --reset-values --timeout 1000s; then
      error_exit "upgrade of $foundations_release has failed"
    fi
  else
    solutions_release=$(helm3 ls --namespace "$NAMESPACE" | grep "$solutions_release_name" | awk '{print $1;exit;}')
    chart_prereq "$chart" # checking solutions pre-install prerequisites.
    run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-upgrade/preUpgrade.sh -n $NAMESPACE -helm2 $helm2" "$solutions_release_name pre-upgrade"
    
    # Set domain before helm upgrade
    set_domain
    
    extraArgs=""
    if [ "X$OpenshiftAuthentication" == "XEnable" ]; then
      extraArgs=",global.roks=true"
    fi
    
    if ! helm3 upgrade --install "$solutions_release" --namespace="$NAMESPACE" --set global.repositoryType="${repository_type}",global.repository="$REPOSITORY",global.cluster.icphostname="$cs_host",global.storageClass="$storageclass",global.license="accept",global.domain.default.domain="$domain",global.adminUserId="${default_admin_user}",global.csNamespace="$cs_namespace",global.imagePullPolicy="${pullPolicy}""$setExtraValues$extraArgs" --values "$base_dir"/ibm-security-solutions-prod/values.yaml "$base_dir"/ibm-security-solutions-prod --reset-values --timeout 1000s; then
      error_exit "upgrade of $solutions_release has failed"
    fi

    sleep 10    
    install_status "$solutions_release_name"
    
    run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $NAMESPACE -helm3 $helm3" "$solutions_release_name post-upgrade"
    # cleanup run
    run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $NAMESPACE -helm3 $helm3 -cleanup" "$solutions_release_name post-upgrade cleanup"
  fi
}

#===  FUNCTION  ================================================================
#   NAME: install_serviceability
#   DESCRIPTION:  install cp-serviceability pod and its dependencies
# ===============================================================================
function install_serviceability() {
    bash ${base_dir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/common/installServiceability.sh -n $NAMESPACE
    if [ $? -ne 0 ]; then
      exit 1
    fi

    echo "[INFO] cp-serviceability SA, Pod and CronJob created"
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
#===  FUNCTION  ================================================================
#   NAME: clean_install
#   DESCRIPTION:  cp4s 1.6 clean install
# ===============================================================================
function clean_install() {
    echo "[INFO] initiating clean install"

    # custom account name only valid for clean install
    if [[ -n "$defaultAccount" ]]; then
        setExtraValues="$setExtraValues,global.defaultAccountName=$defaultAccount"
    fi

    CS_VERSION="$( cat $casepath/inventory/ibmCommonServiceOperatorSetup/resources.yaml |  grep -A 1 'displayName: common-service-operator' | grep tag | awk '{print $2;}')"

    echo "Checking if Common Services $CS_VERSION is already installed"

    CURRENT_CS_VERSION=$(oc get csv -n $cs_namespace | grep ibm-common-service | awk '{print $7;}') 

    if [[ "${CURRENT_CS_VERSION}" == "${CS_VERSION}" ]]; then
        echo "Common Services $CS_VERSION is already installed"
    elif [[ "${CURRENT_CS_VERSION}" == [3-9].[5-9].[0-9] ]]; then
        err_exit "Common Services Version currently installed is not supported by Cloud Pak for Security $CP4S_VERSION"
    else 
        run "$base_dir/cs.sh -cp4sns $NAMESPACE" "common services install"
    fi
    stages=("Install-Common-Services" "Install-Foundations" "Install-Solutions" "Post-Install-Steps")
    list1=()
    csLogin
    ##check status
    status $? Install-Common-Services ${#stages[@]}
    
    restart_community_operators
    install_couchdb
    install_redis
    install_chart "$foundations_release_name"
    ##check status
    status $? Install-Foundations ${#stages[@]}
    
    install_serviceability
    backup_pvc
    
    install_chart "$solutions_release_name"
    
    ##check status
    status $? Install-Solutions ${#stages[@]}

    postinstall_solutions  
    ##check status
    status $? Post-Install-Steps ${#stages[@]}
}


#===  FUNCTION  ================================================================
#   NAME: install
#   DESCRIPTION:  cp4s 1.6 install orchestrator function
# ===============================================================================
function install() {
  oc new-project "$NAMESPACE"
  setEntitlementSecret
  setExtraValues=""

  # handling optional helm parameters
  if [[ -n "$backupStorageClass" ]]; then
      setExtraValues="$setExtraValues,global.backup.storageClass=$backupStorageClass"
  fi
  if [[ -n "$backupStorageSize" ]]; then
      setExtraValues="$setExtraValues,global.backup.size=$backupStorageSize"
  fi
  if [[ "X$securityAdvisor" == "XEnable" ]]; then
      setExtraValues="$setExtraValues,global.ibm-isc-csaadapter-prod.enabled=true"
  fi 
  if [[ -n "$accountDeleteDelay" ]]; then
      setExtraValues="$setExtraValues,global.accountDeleteDelayDays=$accountDeleteDelay"
  fi

  # checking for existance of 1.5.0.0 install
  local release=$(oc get route isc-route-default -n "$NAMESPACE" -o jsonpath="{.metadata.labels.release}" 2>/dev/null)

  if [[ -n $release ]]; then

    local install_version=$(helm3 ls -n "$NAMESPACE" | grep "$release" | awk '{print $NF}')
    local car_version=$(oc get configmap car-version -n "$NAMESPACE" -o jsonpath='{.data.version\.cfg}' 2> /dev/null)

    if [[ "X$install_version" =~ "X1.5" ]]; then
      echo "[INFO] initiating upgrade" 

      install_status=$(helm3 status "$release" -n "$NAMESPACE" |grep -E ^STATUS:)
      if [ "X$install_status" != "XSTATUS: deployed" ]; then
        oc get secret -n "$NAMESPACE" -o name | grep "sh.helm.release.v1.$release" | xargs kubectl -n "$NAMESPACE" delete
      fi          

      stages=("Upgrade-Common-Services" "Upgrade-Foundations" "Upgrade-Solutions" "Post-Upgrade-Validation")
      list1=()

      # CS upgrade script
      run "$base_dir/csUpgrade.sh -cp4sns $NAMESPACE" "Common Services 3.6 upgrade"            
      csLogin      
      ##check status
      status $? Upgrade-Common-Services ${#stages[@]}      

      restart_community_operators      
      install_couchdb
      install_redis
      upgrade_charts "$foundations_release_name"
      ##check status
      status $? Upgrade-Foundations ${#stages[@]}
      
      install_serviceability
      install_status "$foundations_release_name"  
      
      upgrade_charts "$solutions_release_name" 
      ##check status
      status $? Upgrade-Solutions ${#stages[@]}
      
      postinstall_solutions  
      ##check status
      status $? Post-Upgrade-Validation ${#stages[@]}
    elif [ "X$car_version" == "X1500" ]; then
        echo "[INFO] partial upgrade identified, proceeding with postUpgrade steps"
        
        sequences='car'
        failed_seq=()
        for seq in ${sequences[@]}; do
          check_sequence "$seq"
        done      
        
        if [[ -n "${failed_seq[@]}" ]]; then
          error_exit "[ERROR] car sequence is in failed state."
        fi

        run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $NAMESPACE -helm3 $helm3" "$solutions_release_name post-upgrade"
        run "$base_dir/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $NAMESPACE -helm3 $helm3 -cleanup" "$solutions_release_name post-upgrade cleanup"
        
        postinstall_solutions
    else
      # install on top a 1.6.0.0 install
      
      # For Risk Manager
      oc delete job idrmpostgres -n "$NAMESPACE" --ignore-not-found=true
      oc delete pod -ljob-name=idrmpostgres -n "$NAMESPACE" --ignore-not-found=true
          
      clean_install
    fi        
  else
    clean_install
  fi
  route=$(oc get route isc-route-default -n "$NAMESPACE"  --no-headers | awk '{print $2}')
  echo "INFO - Setup LDAP and access the console using your domain $route"
}

#===  CONSTANTS  ================================================================
NAMESPACE=${JOB_NAMESPACE}

if [ "$ENVIRONMENT" == "STAGING" ]; then
  REPOSITORY="cp.stg.icr.io/cp/cp4s"
else
  REPOSITORY='cp.icr.io/cp/cp4s'
fi

if [ -z "${DOCKER_REGISTRY_PASS}" ]; then
  error_exit "entitlement licensing not found"
else
  DOCKER_REGISTRY_USER=${DOCKER_REGISTRY_USER:-ekey}
  DOCKER_REGISTRY_PASS=${DOCKER_REGISTRY_PASS}
fi



repository_type="entitled"
cs_namespace='ibm-common-services'
foundations_release_name="ibm-security-foundations"
solutions_release_name="ibm-security-solutions"
base_dir="$(cd $(dirname $0) && pwd)"
casepath="${base_dir}/../../../.."
# If ROKS is set then parameters cert_file/key_file/custom_ca and domain are optional
OpenshiftAuthentication=${OpenshiftAuthentication}
domain=${domain}
storageclass=${storageClass}
cert_file=${cert}
key_file=${certKey}
custom_ca=${customCA}
default_admin_user=${adminUserId}
securityAdvisor=${securityAdvisor}
backupStorageClass=${backupStorageClass}
backupStorageSize=${backupStorageSize}
pullPolicy=${imagePullPolicy}
defaultAccount=${defaultAccountName}
accountDeleteDelay=${accountDeleteDelayDays}

# ====== MAIN ==========================
run "$base_dir/validation.sh" "catalog install validation" # performs the validation prior to any action
fetchBinaries
fetchCharts
install
