# ibmServiceability for OCP 4.5 and 4.6

## Install ibmServiceability through CP4S Case on OCP 4.5 and 4.6

- To install through the Serviceability case for internal development use

Prerequisite

- casectl - Download casectl cli [here](https://github.ibm.com/CloudPakOpenContent/case-spec-cli/releases) (required)
- cloudctl - Download cloudctl version 3.4.* [here](https://github.com/IBM/cloud-pak-cli/releases/) (required)

Download the ibmServiceability bundle.
```
casectl check items --case ibm-security-foundations-prod/stable/ibm-cp-security-bundle/case/ibm-cp-security -i "ibmSecurityFoundations" --downloadDir <working-directory>/download_dir --force --verbose 2
```


### Install the Case

To install through the Serviceability case, you must provide
- namespace
- required user-specified values


The `ibmServiceability` chart _must_ be installed into the same namespace as the `ibm-security-foundations-prod` chart. Before running the helm installation, run the following command to enter that namespace
```
oc project <NAMESPACE>
```

*Usage* 

```
cloudctl case launch --case stable/ibm-cp-security-bundle/case/ibm-cp-security --namespace <namespace>  --inventory ibmServiceability --action installServiceability --args "--license accept --inputDir  <working-directory>/download_dir"  --tolerance 1
```
