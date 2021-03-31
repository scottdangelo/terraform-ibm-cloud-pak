## Introduction

The IBM Cloud Pak for Security platform uses an infrastructure-independent common operating environment that can be installed and run anywhere. It comprises containerized software pre-integrated with Red Hat OpenShift enterprise application platform, which is trusted and certified by thousands of organizations around the world.

IBM Cloud Pak&reg; for Security can connect disparate data sources — to uncover hidden threats and make better risk-based decisions — while leaving the data where it resides. By using open standards and IBM innovations, IBM Cloud Pak&reg; for Security can securely access IBM and third-party tools to search for threat indicators across any cloud or on-premises location. Connect your workflows with a unified interface so you can respond faster to security incidents. Use IBM Cloud Pak&reg; for Security to orchestrate and automate your security response so that you can better prioritize your team's time.

## What's Inside this Cloud Pak

IBM Cloud Pak&reg; for Security includes the following applications.
  
  - IBM® Threat Intelligence Insights is an application that delivers unique, actionable, and timely threat intelligence. The application provides most of the functions of IBM® X-Force® Exchange.
  - IBM® Security Data Explorer is a platform application that enables customers to do federated search and investigation across their hybrid, multi-cloud environment in a single interface and workflow.
  - IBM® Case Management for IBM Cloud Pak for Security provides organizations with the ability to track, manage, and resolve cybersecurity incidents.
  - IBM® Orchestration & Automation application is integrated on Cloud Pak for Security to provide most of the IBM Resilient Security Orchestration, Automation, and Response Platform feature set.
  - IBM® QRadar® Security Intelligence Platform is offered as an on-premises solution and delivers intelligent security analytics, enabling visibility, detection, and investigation for a wide range of known and unknown threats.
  - IBM® QRadar® Proxy 1.0 provides communication between IBM Cloud Pak for Security and IBM QRadar or QRadar on Cloud. This communication uses APIs to pull powerful QRadar data into the QRadar SIEM dashboards.
  - IBM® QRadar® User Behavior Analytics (UBA) is a tool for detecting insider threats in your organization. UBA, used in conjunction with the existing data in your QRadar system, can help you generate new insights around users and user risk. 
  - IBM® Security Risk Manager provides early visibility into potential security risks by correlating insights from multiple vectors so that you can prioritize risks to take appropriate remedial actions.
  - IBM® Threat Investigator is an application that automatically analyzes and investigates cases to help determine the criticality of exposure, how many systems are at risk, and the level of remediation effort that is required.
  
 For more information see, [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/scp-core/overview.html).

## Prerequisites
Please refer to the `Preparing to install IBM Cloud Pak® for Security` section in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/security-pak/install_prep.html).

## Resources Required
By default, IBM Cloud Pak&reg; for Security has the following resource request requirements per pod:

| Service   | Memory (GB) | CPU (cores) |
| --------- | ----------- | ----------- |
| AITK | 750Mi | 500M | 
| Sequences Operator | 256Mi | 250M |
| Middleware Operator | 256Mi | 250M |
| Middleware Components | 15004Mi | 3650M |
| Entitlements Operator | 100Mi | 50M |
| ISC Truststore | 200Mi | 100M |
| Extension Discovery | 256Mi | 100M |
| Cases | 7846Mi | 820M | 
| Platform | 3046Mi | 1230M |
| DE | 768Mi | 300M |
| CAR | 384Mi | 300M | 
| UDS | 750Mi | 700M |
| TII | 900Mi | 600M |
| TIS | 740Mi | 450M |
| CSA Adapter| 256Mi | 200M |
| Backup | 128Mi | 50M |
| Risk Manager | 2212Mi | 750M |
| Threat Investigator | 843Mi | 260M |

## Storage

Please refer to the `Persistent Storage` section in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/security-pak/persistent_storage.html).

## Installing IBM Cloud Pak&reg; for Security

Please refer to the `Installation` section in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/security-pak/installation.html).

## Verifying the Installation

Please refer to the `Verifying Cloud Pak for Security installation` section in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/security-pak/verification.html).

## Upgrading IBM Cloud Pak&reg; for Security

Please refer to the `Upgrading Cloud Pak for Security` section in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/security-pak/upgrading.html).

## Uninstalling IBM Cloud Pak&reg; for Security

Please refer to the `Uninstalling IBM Cloud Pak for Security` section in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/security-pak/uninstalling_cp4s.html).


## Configuration
Please refer to the `Configuration parameters` table for each type of install in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/security-pak/installation.html).

## Limitations
The IBM Cloud Pak&reg; for Security application can only run on amd64 architecture type.

The IBM Cloud Pak&reg; for Security sets `global.useDynamicProvisioning` to `true`. Dynamic provisioning must not be disabled in the current version.

## Red Hat OpenShift SecurityContextConstraints Requirements
The predefined SecurityContextConstraints name: [`ibm-privileged-scc`](https://ibm.biz/cpkspec-scc) has been verified for IBM Cloud Pak&reg; for Security.

IBM Cloud Pak&reg; for Security requires a SecurityContextConstraints to be bound to the target namespace prior to installation.

IBM Cloud Pak&reg; for Security also defines a custom SecurityContextConstraints object which is used to finely control the permissions/capabilities needed to deploy this chart, the definition of this SCC is shown below:
```yaml
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
allowedCapabilities: []
allowedUnsafeSysctls:
  - net.core.somaxconn
apiVersion: security.openshift.io/v1
defaultAddCapabilities: []
fsGroup:
  ranges:
  - max: 5000
    min: 1000
  type: MustRunAs
groups: []
kind: SecurityContextConstraints
metadata:
  annotations:
    kubernetes.io/description: ibm-isc-scc is a copy of nonroot scc which allows somaxconn changes
  name: ibm-isc-scc
priority: null
readOnlyRootFilesystem: false
requiredDropCapabilities:
- KILL
- MKNOD
- SETUID
- SETGID
runAsUser:
  type: MustRunAsNonRoot
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  ranges:
  - max: 5000
    min: 1000
  type: MustRunAs
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
```

The following script 
```bash
ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh 
```
is run at install time to set the SecurityContextConstraints required by the IBM Cloud Pak&reg; for Security.

## Documentation
Further guidance can be found in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.6.0/platform/docs/kc_welcome_scp.html).
