#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

function print_usage() {
    # Determine context of call (via cloudctl or script directly) based on presence of cananical json parameter
        usage="cloudctl case launch --case <CASE-PATH>"
        caseParmDesc="--case value, -c value      : local path or URL containing the CASE file to parse"
        toleranceParm="--tolerance tolerance"
        toleranceParmDesc="
  --tolerance value, -t value : tolerance level for validating the CASE
                                 0 - maximum validation (default)
                                 1 - reduced valiation"
    echo "
USAGE: ${usage} --inventory inventoryItemOfLauncher --action launchAction
                  --args \"args\" --namespace namespace ${toleranceParm}

OPTIONS:
   --action value, -a value    : the name of the action item launched
   --args value, -r value      : arguments specific to action (see 'Action Parameters' below).
   ${caseParmDesc}
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

    install            
      --license                : set license to accept e.g --license accept (required)
      --chartsDir              : path to saved charts directory (required)
      --helm3                  : path to helm3 cli on client machine e.g /usr/local/bin/helm3 (required)
      --airgap                 : to enable airgap install e.g --airgap (required only for airgap install)
      --debug                  : run install in debug mode
      values.conf              : update config file with required parameters (required)
      --force                  : force a reinstall of CP4S if the same version is already present

    upgrade-all     
      --license                : set license to accept e.g --license accept (required)
      --chartsDir              : path to saved charts directory (required)
      --helm3                  : path to helm3 cli on client machine e.g /usr/local/bin/helm3 (required)
      --helm2                  : path to helm2 cli on client machine e.g /usr/local/bin/helm (required) 
      --debug                  : run install in debug mode

    validate-cp4s     
      --chartsDir              : path to saved charts directory (required)
      --helm3                  : path to helm3 cli on client machine e.g /usr/local/bin/helm3 (required)
      --debug                  : run install in debug mode

    uninstall            
      --chartsDir              : path to saved charts directory (required)
      --helm3                  : path to helm3 cli on client machine (required)
      --debug                  : run install in debug mode

    listConnectors
                               : no params

    getConnector
      --name                   : connector name (required)

    deployConnector            
      --image                  : url to connector docker image (required)
      --type                   : connector type, e.g udi,car (required)
      --registry               : target container image registry (offline)

    deleteConnector
      --name                   : connector name (required)

    restoreConnectors
      --inputDir               : path to saved previous connectors state (required)
"
}
print_usage