#!/usr/bin/env bash
#
# (C) Copyright IBM Corp. 2020  All Rights Reserved.
#
# Script install Redis Operator through the Operator Lifecycle Manager (OLM) or via command line (CLI)
# application of kubernetes manifests in both an online and offline airgap environment.  This script can be invoked using
# `cloudctl`, a command line tool to manage Container Application Software for Enterprises (CASEs), or directly on an
# uncompressed CASE archive.  Running the script through `cloudctl case launch` has added benefit of pre-requisite validation
# and verification of integrity of the CASE.  Cloudctl download and usage istructions are available at [github.com/IBM/cloud-pak-cli](https://github.com/IBM/cloud-pak-cli).
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
caseName="ibm-cloud-databases-redis"
inventory="redisOperator"
instance=""

# - optional parameter / argument defaults
dryRun=""
deleteCRDs=0
namespace=""
registry=""
pass=""
secret=""
user=""
inputcasedir=""
cr_system_status="betterThanYesterday"
recursive_catalog_install=0

# - variables specific to catalog/operator installation
caseCatalogName="ibm-cloud-databases-redis-operator-catalog"
catalogNamespace="openshift-marketplace"
channelName="v1.0"
catalogDigest=":latest"

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
        caseParmDesc="--case value, -c value      : local path or URL containing the CASE file to parse"
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
   --instance value,  -i value : name of instance of target application (release)
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

validate_install_catalog() {

    # using a mode flag to share the validation code between install and uninstall
    local mode="$1"

    echo "Checking arguments for install-catalog action"

    if [[ ${mode} != "uninstall" && -z "${registry}" ]]; then
        err "'--registry' must be specified with the '--args' parameter"
        print_usage 1
    fi

    if [[ ${recursive_catalog_install} -eq 1 && -z "${inputcasedir}" ]]; then
        err "'--inputDir' must be specified with the '--args' parameter when '--recursive' is set"
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

# ***** UTILS *****

assert() {
    testname="$1"
    got=$2
    want=$3
    if [ "$got" != "$want" ]; then
        err_exit "got $got, but want $want : ${testname} failed"
    fi
}
# ***** END UTILS *****

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
        --name "${caseName}" \
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

# Installs the catalog source and operator group of any dependencies
install_dependent_catalogs() {
    echo "No dependency"
}

# Installs the catalog source and operator group
install_catalog() {

    validate_install_catalog

    # install all catalogs of subcases first
    if [[ ${recursive_catalog_install} -eq 1 ]]; then
        install_dependent_catalogs
    fi

    echo "-------------Installing catalog source-------------"

    local catsrc_file="${casePath}"/inventory/"${inventory}"/files/op-olm/catalog_source.yaml
    local opgrp_file="${casePath}"/inventory/"${inventory}"/files/op-olm/operator_group.yaml

    # Verfy expected yaml files for install exit
    validate_file_exists "${catsrc_file}"
    validate_file_exists "${opgrp_file}"

    # Apply yaml files manipulate variable input as required

    local catsrc_image_orig=$(grep "image:" "${catsrc_file}" | awk '{print$2}')

    # replace original registry with local registry
    local catsrc_image_mod="${registry}/$(echo "${catsrc_image_orig}" | sed -e "s/[^/]*\///")"

    # apply catalog source
    sed <"${catsrc_file}" "s|${catsrc_image_orig}|${catsrc_image_mod}|g" | $kubernetesCLI apply -f -

    echo "-------------Installing operator group-------------"

    # apply operator group
    sed <"${opgrp_file}" "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI apply -n "${namespace}" -f -
}

# Install utilizing default OLM method
install_operator() {
    # Verfiy arguments are valid
    validate_install_args

    # Proceed with install
    echo "-------------Installing via OLM-------------"
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-olm/subscription.yaml ]] && { err_exit "Missing required subscription yaml, exiting deployment."; }

    # check if catalog source is installed ?
    if ! $kubernetesCLI get catsrc "${caseCatalogName}" -n "${catalogNamespace}"; then
        err_exit "expected catalog source '${caseCatalogName}' expected to be installed namespace '${catalogNamespace}'"
    fi

    # - subscription
    sed <"${casePath}"/inventory/"${inventory}"/files/op-olm/subscription.yaml "s|REPLACE_NAMESPACE|${namespace}|g" | sed "s|REPLACE_CHANNEL_NAME|$channelName|g" | $kubernetesCLI apply -n "${namespace}" -f -
}

# Install utilizing default CLI method
install_operator_native() {
    # Verfiy arguments are valid
    validate_install_args

    # Proceed with install
    echo "-------------Installing native-------------"
    # Verify expected yaml files for install exist
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-cli/service_account.yaml ]] && { err_exit "Missing required service accout yaml, exiting deployment."; }
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-cli/role.yaml ]] && { err_exit "Missing required role yaml, exiting deployment."; }
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-cli/role_binding.yaml ]] && { err_exit "Missing required rol binding yaml, exiting deployment."; }
    [[ ! -f "${casePath}"/inventory/"${inventory}"/files/op-cli/operator.yaml ]] && { err_exit "Missing required operator yaml, exiting deployment."; }

    # Apply yaml files manipulate variable input as required
    # - service account
    sed <"${casePath}"/inventory/"${inventory}"/files/op-cli/service_account.yaml "s|REPLACE_SECRET|$secret|g" | $kubernetesCLI apply -n "${namespace}" -f -
    # - crds
    for crdYaml in "${casePath}"/inventory/"${inventory}"/files/op-cli/*_crd.yaml; do
        $kubernetesCLI apply -n "${namespace}" -f "${crdYaml}"
    done
    # - role
    $kubernetesCLI apply -n "${namespace}" -f "${casePath}"/inventory/"${inventory}"/files/op-cli/role.yaml
    # - role binding
    sed <"${casePath}"/inventory/"${inventory}"/files/op-cli/role_binding.yaml "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI apply -n "${namespace}" -f -
    # - operator
    $kubernetesCLI apply -n "${namespace}" -f "${casePath}"/inventory/"${inventory}"/files/op-cli/operator.yaml
}

# install operand custom resources
apply_custom_resources() {
    echo "-------------Applying custom resources-------------"
    local cr="${casePath}"/inventory/"${inventory}"/files/redis.databases.cloud.ibm.com_v1_redissentinel_cr.yaml
    [[ ! -f ${cr} ]] && { err_exit "Missing required ${cr}, exiting deployment."; }
    set -e
    sed <"${cr}" "s|systemStatus.*|systemStatus: ${cr_system_status}|g" | $kubernetesCLI apply -n "$namespace" -f -
    set +e
}

# ----- UNINSTALL ACTIONS -----

uninstall_dependent_catalogs() {
    echo "No dependencies"
}

# deletes the catalog source and operator group
uninstall_catalog() {

    validate_install_catalog "uninstall"

    # uninstall all catalogs of subcases first
    if [[ ${recursive_catalog_install} -eq 1 ]]; then
        uninstall_dependent_catalogs
    fi

    local catsrc_file="${casePath}"/inventory/"${inventory}"/files/op-olm/catalog_source.yaml
    local opgrp_file="${casePath}"/inventory/"${inventory}"/files/op-olm/operator_group.yaml

    echo "-------------Uninstalling catalog source-------------"
    $kubernetesCLI delete -f "${catsrc_file}" --ignore-not-found=true

    echo "-------------Uninstalling operator group-------------"
    $kubernetesCLI delete -f "${opgrp_file}" --ignore-not-found=true

}

# Uninstall operator installed via OLM
uninstall_operator() {
    echo "-------------Uninstalling operator-------------"
    # Find installed CSV
    csvName=$($kubernetesCLI get subscription "${caseCatalogName}"-subscription -o go-template --template '{{.status.installedCSV}}' -n "${namespace}" --ignore-not-found=true)
    # Remove the subscription
    $kubernetesCLI delete subscription "${caseCatalogName}-subscription" -n "${namespace}" --ignore-not-found=true
    # Remove the CSV which was generated by the subscription but does not get garbage collected
    [[ -n "${csvName}" ]] && { $kubernetesCLI delete clusterserviceversion "${csvName}" -n "${namespace}" --ignore-not-found=true; }
    # Remove the operatorGroup
    $kubernetesCLI delete OperatorGroup "${caseCatalogName}-group" -n "${namespace}" --ignore-not-found=true
    # delete crds
    if [[ $deleteCRDs -eq 1 ]]; then
        for crdYaml in "${casePath}"/inventory/"${inventory}"/files/op-cli/*_crd.yaml; do
            $kubernetesCLI delete -f "${crdYaml}" --ignore-not-found=true
        done
    fi
}

# Uninstall operator installed via CLI
uninstall_operator_native() {
    echo "-------------Uninstalling operator-------------"
    # Verify expected yaml files for uninstall and delete resources for each
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/service_account.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/service_account.yaml" --ignore-not-found=true; }
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/role.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/role.yaml" --ignore-not-found=true; }
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/role_binding.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/role_binding.yaml" --ignore-not-found=true; }
    [[ -f "${casePath}/inventory/${inventory}/files/op-cli/operator.yaml" ]] && { $kubernetesCLI delete -n "${namespace}" -f "${casePath}/inventory/${inventory}/files/op-cli/operator.yaml" --ignore-not-found=true; }

    # - crds
    if [[ $deleteCRDs -eq 1 ]]; then
        echo "deleting crds"
        for crdYaml in "${casePath}"/inventory/"${inventory}"/files/op-cli/*_crd.yaml; do
            $kubernetesCLI delete -n "${namespace}" -f "${crdYaml}" --ignore-not-found=true
        done
    fi
}

delete_custom_resources() {
    echo "-------------Deleting custom resources-------------"
    local cr="${casePath}"/inventory/"${inventory}"/files/redis.databases.cloud.ibm.com_v1_redissentinel_cr.yaml
    [[ ! -f ${cr} ]] && { err_exit "Missing required ${cr}, exiting deployment."; }
    $kubernetesCLI delete -n "${namespace}" -f "${cr}"
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
