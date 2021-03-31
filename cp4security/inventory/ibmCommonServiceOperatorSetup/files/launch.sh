#!/usr/bin/env bash
#
# (C) Copyright IBM Corp. 2020  All Rights Reserved.
#
# Script install Panamax Operator through the Operator Lifecycle Manager (OLM) or via command line (CLI)
# application of kubernetes manifests in both an online and offline airgap environment.  This script can be invoked using
# `cloudctl`, a command line tool to manage Container Application Software for Enterprises (CASEs), or directly on an
# uncompressed CASE archive.  Running the script through `cloudctl case launch` has added benefit of pre-requisite validation
# and verification of integrity of the CASE.  Cloudctl download and usage instructions are available at [github.com/IBM/cloud-pak-cli](https://github.com/IBM/cloud-pak-cli).
#
# Pre-requisites:
#   oc or kubectl installed
#   sed installed
#   CASE tgz downloaded & uncompressed
#   authenticated to cluster
#
# Parameters are documented within print_usage function.

# ***** GLOBALS *****

# ----- DEFAULTS -----

# Command line tooling & path
kubernetesCLI="oc"
scriptName=$(basename "$0")
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script invocation defaults for parms populated via cloudctl
action="install"
caseJsonFile=""
casePath="${scriptDir}/../../.."
appName="ibm-common-services"
inventory="ibmCommonServiceOperatorSetup"
instance=""

# - optional parameter / argument defaults
dryRun=""
namespace=""
registry=""
pass=""
secret=""
user=""
inputcasedir=""
cr_system_status="betterThanYesterday"

# - variables specific to catalog/operator installation
caseCatalogName="ibm-common-services-catalog"
catalogNamespace="openshift-marketplace"
channelName="stable-v1"
catalogTag="latest"
couchDeployment="deployment.apps/couchdb-operator" #dependency

# Display usage information with return code (if specified)
print_usage() {
    # Determine context of call (via cloudctl or script directly) based on presence of cananical json parameter
    if [ -z "$caseJsonFile" ]; then
        usage="${scriptName} --casePath <CASE-PATH>"
        caseParmDesc="--casePath value, -c value  : root director to extracted CASE file to parse"
        toleranceParm=""
        toleranceParmDesc=""
    else
        usage="cloudctl case launch --case <CASE-PATH>"
        caseParmDesc="--case value, -c value  : local path or URL containing the CASE file to parse"
        toleranceParm="--tolerance tolerance"
        toleranceParmDesc="
  --tolerance value, -t value : tolerance level for validating the CASE
                                 0 - maximum validation (default)
                                 1 - reduced valiation"
    fi
    echo "
USAGE: ${usage} --inventory inventoryItemOfLauncher --action launchAction --instance instance
                  --args \"args\" --namespace namespace ${toleranceParm}

OPTIONS:
   --action value, -a value    : the name of the action item launched
   --args value, -r value      : arguments specific to action (see 'Action Parameters' below).
   ${caseParmDesc}
   --instance value, -i value  : name of instance of target application (release)
   --inventory value, -e value : name of the inventory item launched
   --namespace value, -n value : name of the target namespace
   ${toleranceParmDesc}

 ARGS per Action:
    configure-creds-airgap
      --registry               : source/target container image registry (required)
      --user                   : login user name for the container image registry (required)
      --pass                   : login password for the container image registry (required)

    configure-cluster-airgap
      --dryRun                 : simulate configuration of custer for airgap
      --inputDir               : path to saved CASE directory
      --registry               : target container image registry (required)

    mirror-images
      --dryRun                 : simulate configuration of custer for airgap
      --inputDir               : path to saved CASE directory
      --registry               : target container image registry (required)

    install-catalog:
      --registry               : target container image registry (required)
      --recursive              : recursively install dependent catalogs
      --inputDir               : path to saved CASE directory ( required if --recurse is set)

    install-operator:
      --channelName            : name of channel for subscription (packagemanifest default used if not specified)
      --secret                 : name of existing image pull secret for the container image registry
      --registry               : container image registry (required if pass|user specified)
      --user                   : login user name for the container image registry (required if registry|pass specified)
      --pass                   : login password for the container image registry (required if registry|user specified)

    install-operator-native:
      --secret                 : name of existing image pull secret for the container image registry
      --registry               : container image registry (required if pass|user specified)
      --user                   : login user name for the container image registry (required if registry|pass specified)
      --pass                   : login password for the container image registry (required if registry|user specified)

    uninstall-catalog          : uninstalls the catalog source and operator group
      --recursive              : recursively install dependent catalogs
      --inputDir               : path to saved CASE directory ( required if --recurse is set)

    uninstall-operator         : delete the operator deployment via OLM

    uninstall-operator-native  : deletes the operator deployment via native way
      --deleteCRDs             : deletes CRD's associated with this operator (if not set, crds won't get deleted)

    apply-custom-resources     : creates the sample custom resource
      --systemStatus           : status to display

    delete-custom-resources    : deletes the same custom resource

"

    if [ -z "$1" ]; then
        exit 1
    else
        exit "$1"
    fi
}

# ***** ARGUMENT CHECKS *****

# Validates that the required parameters were specified for script invocation
check_cli_args() {
    # Verify required parameters were specifed and are valid (including environment setup)
    # - case path
    [[ -z "${casePath}" ]] && { err_exit "The case path parameter was not specified."; }
    [[ ! -f "${casePath}/case.yaml" ]] && { err_exit "No case.yaml in the root of the specified case path parameter."; }

    # Verify kubernetes connection and namespace
    check_kube_connection
    [[ -z "${namespace}" ]] && { err_exit "The namespace parameter was not specified."; }
    if ! $kubernetesCLI get namespace "${namespace}" >/dev/null; then
        err_exit "Unable to retrieve namespace specified ${namespace}"
    fi

    # Verify dynamic args are valid (show as any issues on invocation as possible)
    parse_dynamic_args
}

# Parses the args (--args) parameter if any are specified
parse_dynamic_args() {
    _IFS=$IFS
    IFS=" "
    read -ra arr <<<"${1}"
    IFS="$_IFS"
    arr+=("")
    idx=0
    v="${arr[${idx}]}"

    while [ "$v" != "" ]; do
        case $v in
        # Enable debug from cloudctl invocation
        --debug)
            idx=$((idx + 1))
            set -x
            ;;
        --dryRun)
            dryRun="--dry-run"
            ;;
        --deleteCRDs)
            deleteCRDs=1
            ;;
        --channelName)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            channelName="${v}"
            ;;
        --catalogDigest)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            catalogDigest="@${v}"
            ;;
        --registry)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            registry="${v}"
            ;;
        --inputDir)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            inputcasedir="${v}"
            ;;
        --user)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            user="${v}"
            ;;
        --pass)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            pass="${v}"
            ;;
        --secret)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            secret="${v}"
            ;;
        --systemStatus)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            cr_system_status="${v}"
            ;;
        --recursive)
            recursive_catalog_install=1
            ;;
        --help)
            print_usage 0
            ;;
        *)
            err_exit "Invalid Option ${v}" >&2
            ;;
        esac
        idx=$((idx + 1))
        v="${arr[${idx}]}"
    done
}

# Validates that the required args were specified for install action
validate_install_args() {
    # Verify arguments required per install method were provided
    echo "Checking install arguments"

    # Validate secret arguments provided are valid combination and
    #   either create or check for existence of secret in cluster.
    if [[ -n "${registry}" || -n "${user}" || -n "${pass}" ]]; then
        check_secret_params
        set -e
        $kubernetesCLI create secret docker-registry "${secret}" \
            --docker-server="${registry}" \
            --docker-username="${user}" \
            --docker-password="${pass}" \
            --docker-email="${user}" \
            --namespace "${namespace}"
        set +e
    elif [[ -n ${secret} ]]; then
        if ! $kubernetesCLI get secrets "${secret}" -n "${namespace}" >/dev/null 2>&1; then
            err "Secret $secret does not exist, either create one or supply additional registry parameters to create one"
            print_usage 1
        fi
    fi
}
function run(){
    cm=$1
    $cm
    status=$?
    if [ $status -ne 0 ]; then exit 1;fi
} 

validate_install_catalog() {

    # using a mode flag to share the validation code between install and uninstall
    local mode="$1"

    echo "Checking arguments for uninstall/install catalog action"

    if [[ ${mode} != "uninstall" && -z "${registry}" ]]; then
        err "'--registry' must be specified with the '--args' parameter"
        print_usage 1
    fi
}

# Validates that the required args were specified for secret creation
validate_configure_creds_airgap_args() {
    # Verify arguments required to create secret were provided
    local foundError=0
    [[ -z "${registry}" ]] && {
        foundError=1
        err "'--registry' must be specified with the '--args' parameter"
    }
    [[ -z "${user}" ]] && {
        foundError=1
        err "'--user' must be specified with the '--args' parameter"
    }
    [[ -z "${pass}" ]] && {
        foundError=1
        err "'--pass' must be specified with the '--args' parameter"
    }

    # Print usgae if missing parameter
    [[ $foundError -eq 1 ]] && { print_usage 1; }
}

validate_configure_cluster_airgap_args() {
    # Verify arguments required to create secret were provided
    local foundError=0
    [[ -z "${registry}" ]] && {
        foundError=1
        err "'--registry' must be specified with the '--args' parameter"
    }

    [[ -z "${inputcasedir}" ]] && {
        foundError=1
        err "'--inputDir' must be specified with the '--args' parameter"
    }

    # Print usgae if missing parameter
    [[ $foundError -eq 1 ]] && { print_usage 1; }
}

validate_file_exists() {
    local file=$1
    [[ ! -f ${file} ]] && { err_exit "${file} is missing, exiting deployment."; }
}

# ***** END ARGUMENT CHECKS *****

# ***** ACTIONS *****

# ----- CONFIGURE ACTIONS -----

# Add / update local authentication store with user/password specified (~/.airgap/secrets/<registy>.json)
configure_creds_airgap() {
    echo "-------------Configuring authentication secret-------------"

    validate_configure_creds_airgap_args

    # Create registry secret for user information provided

    "${scriptDir}"/airgap.sh registry secret -c -u "${user}" -p "${pass}" "${registry}"
}

# Append secret to Global Cluster Pull Secret (pull-secret in openshif-config)
configure_cluster_pull_secret() {

    echo "-------------Configuring cluster pullsecret-------------"

    # configure global pull secret if an authentication secret exists on disk
    if "${scriptDir}"/airgap.sh registry secret -l | grep "${registry}"; then
        "${scriptDir}"/airgap.sh cluster update-pull-secret --registry "${registry}" "${dryRun}"
    else
        echo "Skipping configuring cluster pullsecret: No authentication exists for ${registry}"
    fi
}

configure_content_image_source_policy() {

    echo "-------------Configuring imagecontentsourcepolicy-------------"

    "${scriptDir}"/airgap.sh cluster apply-image-policy \
        --name "${appName}" \
        --dir "${inputcasedir}" \
        --registry "${registry}" "${dryRun}"
}

# Apply ImageContentSourcePolicy required for airgap
configure_cluster_airgap() {

    echo "-------------Configuring cluster for airgap-------------"

    validate_configure_cluster_airgap_args

    configure_cluster_pull_secret

    configure_content_image_source_policy
}

# ----- MIRROR ACTIONS -----

# Mirror required images
mirror_images() {
    echo "-------------Mirroring images-------------"

    validate_configure_cluster_airgap_args

    "${scriptDir}"/airgap.sh image mirror \
        --dir "${inputcasedir}" \
        --to-registry "${registry}" "${dryRun}"
}

# ----- INSTALL ACTIONS -----

# Installs the catalog source and operator group
install_catalog() {

    validate_install_catalog

    # Verify expected yaml files for install exit
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-olm/online_catalog_source.yaml ]] && { err_exit "Missing required catalog source yaml, exiting deployment."; }
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-olm/operator_group.yaml ]] && { err_exit "Missing required operator group yaml, exiting deployment."; }

    echo "-------------Create catalog source-------------"
    sed <"${casePath}"/inventory/"${inventory}"/files/op-olm/online_catalog_source.yaml "s|REPLACE_TAG|$catalogTag|g" | $kubernetesCLI apply -f -


    # echo "check for any existing operator group in ${namespace} ..."
    # if [[ $($kubernetesCLI get og -n "${namespace}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
    #     echo "found operator group"
    #     $kubernetesCLI get og -n "${namespace}" -o yaml
    #     return
    # fi

    # echo "no existing operator group found"

    # if [[ "$namespace" != "openshift-operators" ]]; then
    #     echo "-------------Create operator group-------------"
    #     sed <"${casePath}"/inventory/"${inventory}"/files/op-olm/operator_group.yaml "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI apply -n "${namespace}" -f -
    # fi
}


# Install utilizing default OLM method
install_operator() {
#    echo "-------------skip-------------"
    wait=30
    maxRetry=20


    echo "check for any existing operator group in ${namespace} ..."
    if [[ $($kubernetesCLI get og -n "${namespace}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
        echo "found operator group"
        $kubernetesCLI get og -n "${namespace}" -o yaml
        return
    fi

    echo "no existing operator group found"

    if [[ "$namespace" != "openshift-operators" ]]; then
        echo "-------------Create operator group-------------"
        sed <"${casePath}"/inventory/"${inventory}"/files/op-olm/operator_group.yaml "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI apply -n "${namespace}" -f -
    fi
    # Proceed with install
    echo "-------------Installing common services via OLM-------------"
    # Verify expected yaml files for install exit
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-olm/subscription.yaml ]] && { err_exit "Missing required subscription yaml, exiting deployment."; }
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-olm/operand_request.yaml ]] && { err_exit "Missing required operand_request yaml, exiting deployment."; }
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-olm/common_service.yaml ]] && { err_exit "Missing required common_service yaml, exiting deployment."; }

    echo "-------------Create common services operator subscription-------------"
    sed <"${casePath}"/inventory/"${inventory}"/files/op-olm/subscription.yaml "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI apply -n "${namespace}" -f -

    # - check if common services operator subscription created
    while true; do
      $kubernetesCLI -n ${namespace} get sub ibm-common-service-operator &>/dev/null && break
      sleep $wait
    done 

    # - check if operand registry cr created
    while true; do
      $kubernetesCLI -n ibm-common-services get opreg common-service &>/dev/null && break
      echo "wait for operand registry cr created ... "
      sleep $wait
    done

    echo "-------------Configure Common Service-------------"
    $kubernetesCLI apply -n ${namespace} -f "${casePath}"/inventory/"${inventory}"/files/op-olm/common_service.yaml

    echo "-------------Create operand request-------------"
    $kubernetesCLI apply -n ibm-common-services -f "${casePath}"/inventory/"${inventory}"/files/op-olm/operand_request.yaml


    echo "-------------Install complete-------------"
}

# Install utilizing default CLI method
install_operator_native() {
    echo "Please use OLM install/uninstall"
}

# install operand custom resources
apply_custom_resources() {
    echo "-------------No custom resources need to apply-------------"
}

# ----- UNINSTALL ACTIONS -----

function delete_sub_csv() {
  subs=$1
  ns=$2
  for sub in ${subs}; do
    csv=$(oc get sub ${sub} -n ${ns} -o=jsonpath='{.status.installedCSV}' --ignore-not-found=true)
    [[ "X${csv}" != "X" ]] && oc delete csv ${csv}  -n ${ns} --ignore-not-found=true
    oc delete sub ${sub} -n ${ns} --ignore-not-found=true
  done
}

function wait_for_deleted(){
  kinds=$1
  ns=${2:---all-namespaces}
  index=0
  retries=${3:-10}
  while true; do
    rc=0
    for kind in ${kinds}; do
      cr=$(oc get ${kind} ${ns} 2>/dev/null)
      rc=$?
      [[ "${rc}" != "0" ]] && break
      [[ "X${cr}" != "X" ]] && rc=99 && break
    done

    if [[ "${rc}" != "0" ]]; then
      [[ $(( $index % 5 )) -eq 0 ]] && echo "Resources are deleting, waiting for complete..."
      if [[ ${index} -eq ${retries} ]]; then
        echo "Timeout for wait all resource deleted"
        return 1
      fi
      sleep 60
      index=$(( index + 1 ))
    else
      echo "All resources have been deleted"
      break
    fi
  done
}

function delete_operand() {
  crds=$1
  ns=$2
  for crd in ${crds}; do
    crs=$(oc get ${crd} --no-headers -n ${ns} 2>/dev/null | awk '{print $1}')
    if [[ "$?" == "0" && "X${crs}" != "X" ]]; then
      echo "Deleting ${crd} kind resource from namespace ${ns}"
      oc delete ${crd} --all -n ${ns} --ignore-not-found=true &
    fi
  done
}

function delete_operand_finalizer() {
  crds=$1
  ns=$2
  for crd in ${crds}; do
    crs=$(oc get ${crd} --no-headers -n ${ns} 2>/dev/null | awk '{print $1}')
    for cr in ${crs}; do
      echo "Removing the finalizers for resource: ${crd} $cr"
      oc patch ${crd} $cr -n ${ns} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]' 2>/dev/null
    done
  done
}

# deletes the catalog source and operator group
uninstall_catalog() {

    validate_install_catalog "uninstall"

    echo "-------------Deleting catalog source-------------"
    $kubernetesCLI delete CatalogSource opencloud-operators -n openshift-marketplace --ignore-not-found=true

    echo "-------------Deleting operatorGroup-------------"
    $kubernetesCLI delete OperatorGroup common-service -n "${namespace}" --ignore-not-found=true

}

# Uninstall operator installed via OLM
uninstall_operator() {
    echo "-------------Uninstalling common services-------------"

    cs_ns="ibm-common-services"
    echo "-------------Deleting common-service OperandRequest from namespace ${cs_ns}...-------------"
    $kubernetesCLI delete OperandRequest common-service -n ${cs_ns} --ignore-not-found=true 2>/dev/null &
    wait_for_deleted OperandRequest "-n ${cs_ns}"

    echo "-------------Deleting ODLM & common service operator sub and csv-------------"
    delete_sub_csv "operand-deployment-lifecycle-manager-app" "openshift-operators"
    delete_sub_csv "ibm-common-service-operator" ${cs_ns}

    echo "-------------Deleting RBAC resource-------------"
    $kubernetesCLI delete ClusterRole ibm-common-service-webhook --ignore-not-found=true
    $kubernetesCLI delete ClusterRoleBinding ibm-common-service-webhook --ignore-not-found=true
    $kubernetesCLI delete RoleBinding ibmcloud-cluster-info -n kube-public --ignore-not-found=true
    $kubernetesCLI delete Role ibmcloud-cluster-info -n kube-public --ignore-not-found=true
    $kubernetesCLI delete RoleBinding ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found=true
    $kubernetesCLI delete Role ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found=true

    $kubernetesCLI delete ClusterRole nginx-ingress-clusterrole --ignore-not-found=true
    $kubernetesCLI delete ClusterRoleBinding $(oc get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found=true
    $kubernetesCLI delete scc nginx-ingress-scc --ignore-not-found=true

    echo "-------------Force deleting operand resources-------------"
    crds=$(oc get crd | grep ibm.com | awk '{print $1}')
    echo "-------------Delete operand resource...-------------"
    delete_operand "${crds}" "${cs_ns}"
    wait_for_deleted "${crds}" "-n ${cs_ns}" 1
    if [[ "$?" != "0" ]]; then
      echo "-------------Delete operand resource finalizer...-------------"
      delete_operand_finalizer "${crds}" "${cs_ns}"
      wait_for_deleted "${crds}" "-n ${cs_ns}" 1
    fi

    subs=$(oc get sub --no-headers -n ${cs_ns} 2>/dev/null | awk '{print $1}')
    delete_sub_csv "${subs}" "${cs_ns}"
    echo "-------------Deleting webhook-------------"
    $kubernetesCLI delete ValidatingWebhookConfiguration -l 'app=ibm-cert-manager-webhook' --ignore-not-found=true

    echo "-------------Deleting catalog source-------------"
    $kubernetesCLI delete CatalogSource opencloud-operators -n openshift-marketplace --ignore-not-found=true

    ## patch/remove mongo pvc and pod as workaround if its hanging 
    for pv in mongodbdir-icp-mongodb-0  mongodbdir-icp-mongodb-1 mongodbdir-icp-mongodb-2;
    do 
      $kubernetesCLI patch pvc $pv -p '{"metadata":{"finalizers":null}}' -n ${namespace} >/dev/null
      $kubernetesCLI delete pvc $pv -n ${namespace} --ignore-not-found=true
    done
    for pod in icp-mongodb-0 icp-mongodb-1 icp-mongodb-2;
    
    do
     $kubernetesCLI patch pod $pod -p '{"metadata":{"finalizers":null}}' -n ibm-common-services >/dev/null
     $kubernetesCLI delete pod --force --grace-period=0 $pod -n ${namespace} >/dev/null
    done

    echo "-------------Deleting namespace-------------"
    $kubernetesCLI delete namespace ${namespace} --ignore-not-found=true
    $kubernetesCLI delete namespace ${cs_ns} --ignore-not-found=true

    echo "-------------Uninstall successful-------------"
}

# Uninstall operator installed via CLI
uninstall_operator_native() {
    echo "Please use OLM install/uninstall"
}

delete_custom_resources() {
    echo "-------------No custom resources need to delete-------------"
}

# ***** END ACTIONS *****

# Verifies that we have a connection to the Kubernetes cluster
check_kube_connection() {
    # Check if default oc CLI is available and if not fall back to kubectl
    command -v $kubernetesCLI >/dev/null 2>&1 || { kubernetesCLI="kubectl"; }
    command -v $kubernetesCLI >/dev/null 2>&1 || { err_exut "No kubernetes cli found - tried oc and kubectl"; }

    # Query apiservices to verify connectivity
    if ! $kubernetesCLI get apiservices >/dev/null 2>&1; then
        # Developer note: A kubernetes CLI should be included in your prereqs.yaml as a client prereq if it is required for your script.
        err_exit "Verify that $kubernetesCLI is installed and you are connected to a Kubernetes cluster."
    fi
}

# Run the action specified
run_action() {
    echo "Executing inventory item ${inventory}, action ${action} : ${scriptName}"
    case $action in
    configureCredsAirgap)
        configure_creds_airgap
        ;;
    configureClusterAirgap)
        configure_cluster_airgap
        ;;
    installCatalog)
        install_catalog
        ;;
    installOperator)
        install_operator
        ;;
    installOperatorNative)
        install_operator_native
        ;;
    mirrorImages)
        mirror_images
        ;;
    uninstallCatalog)
        uninstall_catalog
        ;;
    uninstallOperator)
        uninstall_operator
        ;;
    uninstallOperatorNative)
        uninstall_operator_native
        ;;
    applyCustomResources)
        apply_custom_resources
        ;;
    deleteCustomResources)
        delete_custom_resources
        ;;
    *)
        err "Invalid Action ${action}" >&2
        print_usage 1
        ;;
    esac
}

# Error reporting functions
err() {
    echo >&2 "[ERROR] $1"
}
err_exit() {
    echo >&2 "[ERROR] $1"
    exit 1
}

# Parse CLI parameters
while [ "${1-}" != "" ]; do
    case $1 in
    # Supported parameters for cloudctl & direct script invocation
    --casePath | -c)
        shift
        casePath="${1}"
        ;;
    --caseJsonFile)
        shift
        caseJsonFile="${1}"
        ;;
    --inventory | -e)
        shift
        inventory="${1}"
        ;;
    --action | -a)
        shift
        action="${1}"
        ;;
    --namespace | -n)
        shift
        namespace="${1}"
        ;;
    --instance | -i)
        shift
        instance="${1}"
        ;;
    --args | -r)
        shift
        parse_dynamic_args "${1}"
        ;;

    # Additional supported parameters for direct script invocation ONLY
    --help)
        print_usage 0
        ;;
    --debug)
        set -x
        ;;

    *)
        echo "Invalid Option ${1}" >&2
        exit 1
        ;;
    esac
    shift
done

# Execution order
check_cli_args
run_action
