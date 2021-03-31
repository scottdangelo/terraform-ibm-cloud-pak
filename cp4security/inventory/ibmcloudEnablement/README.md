# Introduction
IBM Cloud Pak® for Security can connect disparate data sources—to uncover hidden threats and make better risk-based decisions — while leaving the data where it resides. By using open standards and IBM innovations, IBM Cloud Pak® for Security can securely access IBM and third-party tools to search for threat indicators across any cloud or on-premises location. Connect your workflows with a unified interface so you can respond faster to security incidents. Use IBM Cloud Pak® for Security to orchestrate and automate your security response so that you can better prioritize your team's time.

## What's inside this Cloud Pak

Cloud Pak® for Security includes the following applications.
  
  - IBM® Threat Intelligence Insights is an application that delivers unique, actionable, and timely threat intelligence. The application provides most of the functions of IBM® X-Force® Exchange.
  - IBM® Security Data Explorer is a platform application that enables customers to do federated search and investigation across their hybrid, multi-cloud environment in a single interface and workflow.
  - IBM® Case Management for IBM Cloud Pak for Security provides organizations with the ability to track, manage, and resolve cybersecurity incidents.
  - IBM® Orchestration & Automation application is integrated on Cloud Pak for Security to provide most of the IBM Resilient Security Orchestration, Automation, and Response Platform feature set.
  - IBM® QRadar® Security Intelligence Platform is offered as an on-premises solution and delivers intelligent security analytics, enabling visibility, detection, and investigation for a wide range of known and unknown threats.
  - IBM® QRadar® Proxy 1.0 provides communication between IBM Cloud Pak for Security and IBM QRadar or QRadar on Cloud. This communication uses APIs to pull powerful QRadar data into the QRadar SIEM dashboards.
  - IBM® QRadar® User Behavior Analytics (UBA) is a tool for detecting insider threats in your organization. UBA, used in conjunction with the existing data in your QRadar system, can help you generate new insights around users and user risk. 
  - IBM® Security Risk Manager provides early visibility into potential security risks by correlating insights from multiple vectors so that you can prioritize risks to take appropriate remedial actions.
  - IBM® Threat Investigator is an application that automatically analyzes and investigates cases to help determine the criticality of exposure, how many systems are at risk, and the level of remediation effort that is required.
  
 For more information, see [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0/platform/docs/scp-core/overview.html).
 
# Prerequisites

## Red Hat OpenShift Container Platform

Please refer to the `Planning` section in the [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSTDPP_1.6.0).

## Resource capacity requirements

| Node type | Number of nodes | CPU | RAM | Storage |
| --------- | ----------- | ----------- | ----------- | ----------- |
  Worker | 4 | 8 cores | 32 GB | 120 GB |

## Purchasing a license

Before you can install the Cloud Pak, you must purchase a license. Purchase a license, also known as an entitlement, through [IBM Passport Advantage](https://www.ibm.com/software/passportadvantage/index.html).

# Installing

For installation instructions, see  https://cloud.ibm.com/docs/cloud-pak-security. The installation takes approximately 1.5 hours to complete.

## Configuration

The following table lists the configurable parameters of the navigator chart and their default values.

| Required Values | Description |
| --------- | ----------- |
| adminUserId | Cloud Pak for Security Administrator |

| Optional Values  | Description | Default
| --------- | ----------- | ----------- |
| domain | Cloud Pak for Security Application URL. If blank, Openshift domain cp4s.\<your-cluster-subdomain\> and certificates are used |
| cert | Cloud Pak for Security Domain TLS Certificate. Required when \<domain\> is set. [See more](https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.6.0/platform/docs/security-pak/tls_certs.html) |
| certKey | Cloud Pak for Security Domain TLS Certificate Key. Required when \<domain\> is set. [See more](https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.6.0/platform/docs/security-pak/tls_certs.html) |
| customCA | Custom Certificate of Authority (CA) for Non-Trusted Certificate. [See more](https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.6.0/platform/docs/security-pak/tls_certs.html) | nil |
| OpenshiftAuthentication | Enable Openshift IAM Integration | Disable |
| storageClass | Cloud Pak for Security Default Storage Class | ibmc-block-gold |
| securityAdvisor | Deploy Security Advisor | Disable |
| backupStorageClass | Cloud Pak for Security Backup Storage Class | Value set in `storageClass` |
| backupStorageSize | Cloud Pak for Security Backup Storage Size | 100 GB |
| imagePullPolicy | Cloud Pak for Security Image Pull Policy | Always |
| defaultAccountName | Cloud Pak for Security Account Name | Cloud Pak For Security |

# Documentation
Documentation for Cloud Pak&reg; for Security can be found at https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.6.0/platform/docs/kc_welcome_scp.html 
