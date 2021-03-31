# IBM Common Service Operator

# Introduction

When you install this operator:

1. ODLM will be installed in all namespaces mode
1. `ibm-common-services` namespace will be created
1. OperandRegistry and OperandConfig of Common Services will be created under `ibm-common-services` namespace

## Summary

* IBM Common Service Operator is used to install the common services.

## Features

- IBM Common Service Operator is a bridge to connect CloudPaks and ODLM/Common Services, and it can be also installed in standalone mode.
- Operand Deployment Lifecycle Manager is used to manage the lifecycle of a group of operands.

# Details

## Supported platforms

Red Hat OpenShift Container Platform 4.3 or newer installed on one of the following platforms:

   - Linux x86_64
   - Linux on Power (ppc64le)

## Prerequisites

### Resources Required

#### Minimum scheduling capacity

| Software                   | Memory (MB) | CPU (cores) | Disk (GB) | Nodes  |
| -------------------------- | ----------- | ----------- | --------- | ------ |
| ibm common service operator | 200          | 0.2        | 1          | worker |
| **Total**                  | 200         | 0.2         | 1         |        |

# Installing

For installation, see the [IBM Cloud Platform Common Services documentation](http://ibm.biz/cpcsdocs).

## Configuration

For configuration, see the [IBM Cloud Platform Common Services documentation](http://ibm.biz/cpcsdocs).

## Storage

* No volume dependency.

## Limitations

* Deployment limits - can only deploy one instance in each cluster.

## Documentation

* Refer to [IBM Cloud Platform Common Services documentation](http://ibm.biz/cpcsdocs) for installation and configuration.

## SecurityContextConstraints Requirements

The IBM Common Service Operator supports running with the OpenShift Container Platform 4.3 default restricted Security Context Constraints (SCCs) and IBM Cloud Pak Security Context Constraints (SCCs).

For more information about the OpenShift Container Platform Security Context Constraints, see [Managing Security Context Constraints](https://docs.openshift.com/container-platform/4.3/authentication/managing-security-context-constraints.html).

For more information about the IBM Cloud Pak Security Context Constraints, see [Managing Security Context Constraints](https://ibm.biz/cpkspec-scc).
