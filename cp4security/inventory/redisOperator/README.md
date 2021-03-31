# redisOperatorSetup for OCP 4.5 and 4.6

## Install Redis operator through CP4S Case on OCP 4.5 and 4.6

- To install through the Cloud Pack for Security Foundations case for internal development use


Prerequisite

- casectl - Download casectl cli [here](https://github.ibm.com/CloudPakOpenContent/case-spec-cli/releases) (required)
- cloudctl - Download cloudctl version 3.4.* [here](https://github.com/IBM/cloud-pak-cli/releases/) (required)

Download the redis bundle.
```
casectl check items --case ibm-security-foundations-prod/stable/ibm-cp-security-bundle/case/ibm-cp-security -i "redisOperator" --downloadDir <working-directory>/download_dir --force --verbose 2
```
**NOTE**: Output of above command may include the following:
```
[ERROR]: Unable to validate the digest for ibm-cloud-databases-redis-1.0.1 against anything in the digests yaml
```
This should be **ignored**.


*Usage* 
Install the operator:
```
cloudctl case launch --case stable/ibm-cp-security-bundle/case/ibm-cp-security --namespace <namespace>  --inventory installProduct --action install-redisoperator --args "--license accept --devmode --registry cp.icr.io --user <entitled-registry-username> --pass <entitlement-registry-password> --inputDir <working-directory>/download_dir"  --tolerance 1
```

## Uninstall the operator:

```
cloudctl case launch --case stable/ibm-cp-security-bundle/case/ibm-cp-security --namespace <namespace>  --inventory installProduct --action uninstall-redisoperator --args "--license accept --inputDir <working-directory>/download_dir"  --tolerance 1
```

