# couchdbOperatorSetup for OCP 4.5 and 4.6

## Install CouchDB operator through CP4S Case on OCP 4.5 and 4.6

Prerequisite

- casectl - Download casectl cli [here](https://github.ibm.com/CloudPakOpenContent/case-spec-cli/releases) (required)
- cloudctl - Download cloudctl version 3.4.* [here](https://github.com/IBM/cloud-pak-cli/releases/) (required)

Download the Couchdb bundle.
```
casectl check items --case ibm-security-foundations-prod/stable/ibm-cp-security-bundle/case/ibm-cp-security -i "couchdbOperatorSetup" --downloadDir <working-directory>/download_dir --force --verbose 2
```
**NOTE**: Output of above command may include the following:
```
[ERROR]: Unable to validate the digest for ibm-couchdb-1.0.0 against anything in the digests yaml
```
This should be **ignored**.

- To install through the Cloud Pack for Security Foundations case 

*Usage* 

```
cloudctl case launch --case stable/ibm-cp-security-bundle/case/ibm-cp-security --namespace <namespace>  --inventory installProduct --action install-couchdboperator --args "--license accept --inputDir <working-directory>/download_dir"  --tolerance 1
```
## Uninstall Couchdboperator

```
cloudctl case launch --case stable/ibm-cp-security-bundle/case/ibm-cp-security --namespace <namespace>  --inventory installProduct --action uninstall-couchdboperator --args "--license accept --inputDir <working-directory>/download_dir"  --tolerance 1
```


