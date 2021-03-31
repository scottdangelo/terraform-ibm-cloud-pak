# IBM Security Foundations
This readme provides instructions on how to manually install and configure the Kubernetes cluster to install IBM Security Foundations as part of the  CloudPak for Security.

# Installation

## Installing the Chart

### Run the pre-install script

The script `preInstall.sh`:
-  Enables the pods to execute with the correct security privileges
-  Creates an image pull secret to pull images from a repository

Before running the script, log in to the cluster.

Run the script as follows:
```
ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh [ arguments ] 
```

where arguments may be


| Argument| Description
|---------|-------------
| -n NAMESPACE | Change namespace from current
| -force | Force update of the existing cluster configuration
| -repo REPOSITORY REPO_USERNAME REPO_PASSWORD | Set the image repository and repository credentials as documented per install type (Entitled Registry or PPA)
| -sysctl | Enable net.core.somaxconn sysctl change
| -ibmcloud | Indicates target environment is IBM Cloud


Note:  `-ibmcloud` option is mutually exclusive with `-sysctl` option. 
  
### Check Prerequisites	

A script is provided which should be run to validate pre-requisites before beginning the install of `ibm-security-foundations-prod`. 	


This script is run with the following command : 	

```	
ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/checkprereq.sh -n <NAMESPACE> 	
```	

Output will display the default storage class and when successfull will indicate : 	

```	
INFO: ibm-security-foundations prerequisites are OK	
```	

*Note*: If this script is run immediately after the `preInstall.sh` you may see the error : 
```
ERROR: worker nodes are still updating
```
This is expected while the nodes are updating, please wait a few minutes for the task to complete and then re-run the `checkprereq.sh` script.

Any errors should be resolved before continuing.

### Install the Chart

To install the chart, you must provide
- a release name (e.g. `ibm-security-foundations-prod`)
- namespace (as you selected above)
- required user-specified values

Important user-specified values are:

| Parameter | Note | 
| --- | --- |
| `global.helmUser` | Required |
| `global.repository` | Required if installing [using IBM Passport Advantage](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.3.0/docs/security-pak/ppa_download.html), you must specify a docker registry host (and path if relevant). Note that the repository you specify here must match the repository specified in [Run the pre-install script](#run-the-pre-install-script) above. |
| `global.repositoryType` | If installing from Passport Advantage archives, change to `local` |
| `global.cloudType` | Required if installing to a cloud platform such as IBM Cloud or AWS rather than a Red Hat OpenShift Container Platform |

The full set of configuration values are in the [Configuration table](#configuration).

To specify values for a command line installation, either edit the values file or pass the values on the command line.

To edit the values file
- Edit the `ibm-security-foundations-prod/values.yaml` file (or optionally copy the file to another directory)
- Run the helm command with the additional option `--values <PATH>/values.yaml`

To pass the values on the command line
- Run the helm command with an additional `--set <VARNAME>=<VALUE>` option for each value
- For example: `--set global.helmUser=my-rhel-admin [...]`

Before running the helm install, log in to the cluster and set the namespace.

To install the chart run the following command:
```
helm install --name <RELEASE_NAME> --namespace=<NAMESPACE>  ./ibm-security-foundations-prod --tls --values <PATH>/values.yaml [--set options]
```
                     
### Verifying the Chart

Once the install of `ibm-security-foundations-prod` has completed, to verify the outcome execute the following:

1. Using the <RELEASE_NAME> specified, the following commands can be used to view the status of the installation.

    a. `helm ls <RELEASE_NAME> --tls`
    
    __Expected Result:__ The `ibm-security-foundations-prod` should be in a `Deployed` state.

    b. `helm status <RELEASE_NAME> --tls`
    
     __Expected Result:__ The `ibm-security-foundations-prod` resources should listed as `STATUS: DEPLOYED` and list  all resources deployed.

    c. Execute the helm tests to verify installation  ```helm test <RELEASE_NAME> –cleanup --tls```

    __Expected Results:__

       
        Testing ibm-security-foundations:
        -----------------------------------------------------
        RUNNING: ibm-security-foundations-sequences-test
        PASSED: ibm-security-foundations-sequences-test
        RUNNING: ibm-security-foundations-extension-test
        PASSED: ibm-security-foundations-extension-test
        RUNNING: ibm-security-foundations-middleware-test
        PASSED: ibm-security-foundations-middleware-test
        =====================================================
        Following charts have PASSED: 
        ibm-security-foundations
        

    d. Monitor status of the pods until they are in a  `Running` State 

      ```kubectl get pods -l release=<RELEASE> --watch```


### Upgrade or update the installation

If you have previously installed Cloud Pak for Security, you can upgrade to a later version of the software or apply updates to configuration values by running the helm `upgrade` command.


Prior to executing the `helm upgrade` command below complete the steps in [Check prerequisites](#check-prerequisites)

Then run the command:
```
helm upgrade <RELEASE_NAME> --namespace=<NAMESPACE>  ./ibm-security-foundations-prod --tls --values <PATH>/values.yaml [--set options]
```

where passing `--values <PATH>/values.yaml` and `[--set options]` are as described in [Install the chart](#install-the-chart) above.


### Uninstalling the chart

Before running these steps log in to the cluster and set the namespace.

To uninstall and delete the `ibm-security-foundations-prod` release, run the following command:

```
helm delete <RELEASE_NAME> --purge --tls
```

Then the post-delete script must be run as follows:
```
ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/post-delete/Cleanup.sh -n <NAMESPACE> --all --force
```

Any errors in the output of this script (other than a Usage error) can be safely ignored.
