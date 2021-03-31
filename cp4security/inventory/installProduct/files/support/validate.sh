#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************
## Function to check install status of charts
export CS_NAMESPACE="ibm-common-services"

function check_sequence() {
  local seq=$1
  sequence_status=$(oc get iscsequence "$seq" -n "$namespace" 2>/dev/null | awk 'FNR == 2 {print $2}')

  # avoid deadlock if sequence gets deleted during check_sequence()
  if [ "X$sequence_status" == "X" ]; then return; fi 
    
  guard_id=$(kubectl get iscguard "$seq" -o 'jsonpath={.spec.generation}' 2>/dev/null)
  seq_id=$(kubectl get iscsequence "$seq" -o 'jsonpath={.spec.labels.generation}' 2>/dev/null)  

  until [[ "X$guard_id" == "X$seq_id" || "$sequence_status" =~ "Failed" ]]
  do
    sequence_status=$(oc get iscsequence "$seq" -n "$namespace" | awk 'FNR == 2 {print $2}')
    guard_id=$(kubectl get iscguard "$seq" -o 'jsonpath={.spec.generation}' 2>/dev/null)
    running_sequence=$(oc get iscsequence -n "$namespace" | grep Running | awk '{print $1}')
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
function install_status(){
  local chart=$1
  local helm=$2
  local maxRetry=20
  local to_retry
  local release_name=$(${helm3} ls --namespace "$namespace" | grep "$chart" | awk '{print $1}')
  if [[ $chart == *"ibm-security-foundations"* ]]; then
      ## check if release_name returned something 
      if [[ -z "$release_name" ]]; then
         echo "$chart chart release not found"
      else

        for ((retry=0;retry<=${maxRetry};retry++)); 
        do
          notRunning=()
          running=()
          stats=$($kubernetesCLI get pod -n "$namespace" -lrelease="$release_name" --no-headers | awk '{print $3}')
          for stat in ${stats[*]};
          do
            # status=$($kubernetesCLI get pod $pod -n "$namespace"  | awk 'FNR == 2 {print $3}')
            if [[ $stat != "Running" ]]; then
                  pod=$($kubernetesCLI get pod -n "$namespace" -lrelease="$release_name" | grep "$stat" | awk '{print $1}')
                  notRunning+=("$pod") 
            else 
                running+=("$pod")            
            fi
          done

          if [[ -z ${notRunning[*]} ]]; then
              echo "INFO - All foundations pods are running ok"
              break
          else
              echo "INFO - Waiting for pods to go into running state "
              sleep 20
          fi
    
          if [ ${retry} -eq ${maxRetry} ]; then
              err_exit "timed out waiting for pods to go into running state"
          fi
        done
      fi



  else 
      if [[ -z "$release_name" ]]; then
         echo "$chart chart release not found"
      else
        successful_seq=()
        failed_seq=()
        ### LIST SEQUENCE
        echo "INFO - Install Status of ibm-security-solutions"
        sequence_list=$($kubernetesCLI get iscsequence -n "$namespace" --no-headers | awk '{print $1}' | sort)
        ### Check the status of all sequence
        for seq in ${sequence_list[*]}
        do
          check_sequence "$seq"
        done
        # retry failed sequences
        to_retry=("${failed_seq[*]}")
        failed_seq=()
        for seq in ${to_retry[*]}; do 
          sequence_status=$(oc get iscsequence "$seq" -n "$namespace" | awk 'FNR == 2 {print $2}')
          if [[ ! $sequence_status == *"Successful"* ]]; then      
            bash "${chartsDir}"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/runseq.sh "$seq"
            echo "INFO - Restarting $seq sequence"
            sleep 160
            check_sequence "$seq"
          fi        
        done
          ### Check status of cases
        cases_pods=$($kubernetesCLI get pod -n "$namespace" --no-headers | grep cases | awk '{print $1}')
        for var in ${cases_pods[*]}
        do
          cases_pods_status=$($kubernetesCLI get pod "$var" -n "$namespace" | awk 'FNR == 2 {print $3}')
          if [[ $cases_pods_status =~ "Running" || $cases_pods_status =~ "Completed" ]]; then
              echo "INFO - $var pod is $cases_pods_status"
          else
              echo "INFO - $var  pod status is $cases_pods_status"
        fi
        done
        ### Double check sequence
        if [[ -n ${failed_seq[*]} ]]; then 
           latest_failed_seq=()
           for i in ${failed_seq[*]}; do
             latest_status=$(oc get iscsequence "$i" -n "$namespace" | awk 'FNR == 2 {print $2}')
             if [[ $latest_status == *"Failed"*  ]]; then
                latest_failed_seq+=("$i")
             fi
           done
        fi
                 
    
        route=$($kubernetesCLI get route isc-route-default -n "$namespace"  --no-headers | awk '{print $2}')
        checkcr=$(bash "${chartsDir}"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/checkcr.sh -n "$namespace" --all)
        if [[ $checkcr =~ "Failed" ]] || [[ $checkcr == *"non-running"* ]] || [[ $checkcr =~ "Error" ]]; then

          if [[ -z "${latest_failed_seq[*]}" ]]; then
              echo "INFO - Setup LDAP and access the console using your domain $route"
              echo "WARNING All sequence finished Sucessfully but problems with crs. ${checkcr[*]}"
          else
              err "Problem with $chart installation"
              err "The following sequence have failed: ${latest_failed_seq[*]}"
              err_exit "Output of checkcr.sh: ${checkcr[*]}"
          fi
              

        else
            if [[ -z "${latest_failed_seq[*]}" ]]; then
                echo "INFO - All sequence finished Sucessfully"
                echo "INFO - Setup LDAP and access the console using your domain $route"
            else
              err "Problem with $chart installation"
              err "The following sequence have failed: ${failed_seq[*]}"
              err_exit "${checkcr[*]}"
            fi
            
        fi
      fi
  fi
  if [[ $helm == "-helmtest" ]]; then
    if ! ${helm3} test "$release_name" --timeout 800s; then
        err "$release_name test has failed"
    fi
    sleep 5
    ## cleanup tests pod hanging around
    $kubernetesCLI get pod -n "$namespace" --no-headers | grep "test" | awk '{print $1}' | xargs $kubernetesCLI delete pod >/dev/null
  fi
  }


function validate_redis(){
   maxRetry=20
   for ((retry=0;retry<=${maxRetry};retry++)); do
        
      echo "INFO - Waiting for Redis operator pod initialization"         
       
      isReady=$($kubernetesCLI get pod -n "$namespace" -lname=ibm-cloud-databases-redis-operator --no-headers | grep "Running")
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
          err_exit "Timeout Waiting for Redis operator to start"
        else
          sleep 30
          continue
        fi
      else
        echo "INFO - Redis operator is running $isReady"
        break
      fi
  done
}

## Function to validate couchdb 
function validate_couchdb(){
   maxRetry=20
   for ((retry=0;retry<=${maxRetry};retry++)); do
        
      echo "INFO - Waiting for Couchdb operator pod initialization"         
       
      isReady=$($kubernetesCLI get pod -n "$namespace" -lname=couchdb-operator --no-headers | grep "Running")
      if [[ -z $isReady ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
          err_exit "Timeout Waiting for couchdboperator to start"
        else
          sleep 30
          continue
        fi
      else
        echo "INFO - Couchdb operator is running $isReady"
        break
      fi
  done
}

# function to validate common services
function validate_cs(){

    maxRetry=30

    for ((retry=0;retry<=${maxRetry};retry++)); 
    do
      echo "INFO- waiting common services csv initialization"
      nonReady=$(oc -n $CS_NAMESPACE get csv --no-headers | awk '{print $NF}' | grep -v "Succeeded" | wc -l)
      succeeded=$(oc -n $CS_NAMESPACE get csv --no-headers | awk '{print $NF}' | grep -c "Succeeded")
      if [[ $nonReady -ne 0 ]] && [[ $succeeded -lt 9 ]]; then # expecting at least 8 CSVs to consider success
        if [[ $retry -eq ${maxRetry} ]]; then 
            err_exit "common services CSV initialization failed"
        else
            sleep 60
            continue
        fi
      else
        echo "INFO common services CSV install completed"
        break
      fi
    done   

    # Additional slep to allow pods to initialise before the check
    sleep 240

    for ((retry=0;retry<=${maxRetry};retry++)); do

      echo "INFO - Waiting Common Services Pods initialization"    
  
      nonReady=$(oc get pod --no-headers -n $CS_NAMESPACE | grep -Ev "Running|Completed" | wc -l)
      if [[ $nonReady -ne 0 ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
          err_exit " Error on Common Services Pods Startup."
        else
          sleep 60
          continue
        fi
      else
        echo "INFO - Common Services Installed"
        break
      fi
    done
    
    # giving auth pods time for getting into Ready state
    sleep 60    
}
## error functions
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
    -couchdb)
      validate_couchdb
      ;;
    -redis)
      validate_redis
      ;; 
    -eventstreams)
      validate_eventstreams
      ;; 
    -chart)
      chart=$1
      run_helm_test=$2
      shift
      shift
      install_status "$chart" "$run_helm_test"
      ;;
    -cs)
      validate_cs
      ;;
    *)
      echo "ERROR: Invalid argument: $arg"
      exit 1
      ;;
  esac
done
