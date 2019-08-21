#!/bin/bash

THIS_REPO="nalbam"
THIS_NAME="kube-cui"
THIS_VERSION="v0.0.0"

DEBUG_MODE=true

CONFIG=
CONFIG_SAVE=

ANSWER=
CLUSTER=

REGION=
AZ_LIST=

KOPS_STATE_STORE=
KOPS_CLUSTER_NAME=
KOPS_TERRAFORM=

CLUSTER_NAME=

ROOT_DOMAIN=
BASE_DOMAIN=

CERT_MAN=
EFS_ID=
ISTIO=

cloud=aws
master_size=c4.large
master_count=1
master_zones=
node_size=m4.large
node_count=2
zones=
network_cidr=10.0.0.0/16
networking=calico
topology=public
dns_zone=
vpc=
