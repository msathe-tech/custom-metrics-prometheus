#!/usr/bin/env bash
# Copyright 2021 Google LLC
#
# This software is provided as-is, without warranty or representation for any use or purpose.
# Your use of it is subject to your agreement with Google.
#

set -e

# These must be set as environment variables or on the command line
# CLUSTER_NUM
# COUNTRY
# FRANCHISE_ID
# PROJECT_ID
# STORE_ID

SSH_USER="abm-admin"

usage() {
  {
    echo "$0 --country=[country] --franchise-id=[franchise_id] --store-id=[store_id] --host=[HOSTNAME]"
    echo "Or: COUNTRY=[country] FRANCHISE_ID=[franchise_id] STORE_ID=[store_id] CLUSTER_NUM=[cluster_num] $0"
    echo "-c,--country: Country store is located in. COUNTRY environment variable."
    echo "-f,--franchise,--franchise-id: Franchise store belongs to. FRANCHISE_ID environment variable."
    echo "-k,--key: SSH public key location. Defaults to ~/.ssh/cnucs-cloud.pub"
    echo "-h,--host: Remote CNUC name or IP address"
    echo "-p,--project,--project-id: Project ID. PROJECT_ID environment variable."
    echo "-s,--store,--store-id: Store ID. STORE_ID environment variable."
  } 1>&2
}

# Process arguments
for i in "$@"
do
  case $i in
    -c=* | --country=*)
      COUNTRY="${i#*=}"
      shift
      ;;
    -f=* | --franchise=* | --franchise-id=*)
      FRANCHISE_ID="${i#*=}"
      shift
      ;;
    -h=* | --host=*)
      HOST="${i#*=}"
      shift
      ;;
    -k=* | --key=*)
      SSH_PUB_KEY_LOCATION="${i#*=}"
      shift
      ;;
    -p=* | --project=* | --project-id=*)
      PROJECT_ID="${i#*=}"
      shift
      ;;
    -s=* | --store=* | --store-id=*)
      STORE_ID="${i#*=}"
      shift
      ;;
    *)
      usage
      exit 1
  esac
done

ERROR=0
if [[ -z "${COUNTRY}" ]]; then
  echo "Error: COUNTRY is not set" 1>&2
  ERROR=1
fi

if [[ -z "${FRANCHISE_ID}" ]]; then
  echo "Error: FRANCHISE_ID is not set" 1>&2
  ERROR=1
fi

if [[ -z "${HOST}" ]]; then
  echo "Error: HOST is not set" 1>&2
  ERROR=1
fi

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Error: PROJECT_ID is not set" 1>&2
  ERROR=1
fi

if [[ -z "${STORE_ID}" ]]; then
  echo "Error: STORE_ID is not set" 1>&2
  ERROR=1
fi

if [[ "${ERROR}" -eq 1 ]]; then
  usage
  exit 1
fi

if [[ -z "${SSH_PUB_KEY_LOCATION}" ]]; then
  SSH_PUB_KEY_LOCATION=$HOME/.ssh/cnucs-cloud.pub
fi

GCP_SA="prometheus-stackdriver@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Configuration:"
echo "COUNTRY: ${COUNTRY}"
echo "FRANCHISE_ID: ${FRANCHISE_ID}"
echo "STORE_ID: ${STORE_ID}"
echo "PROJECT_ID: ${PROJECT_ID}"
echo "HOST: ${HOST}"

# -- to handle directories starting with -
SCRIPT_DIR=$(dirname -- "$0")
CLUSTER_RESOURCES="${SCRIPT_DIR}/cluster-resources/store-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}"

if [[ ! -d ${CLUSTER_RESOURCES} ]]; then
  echo "Error: ${CLUSTER_RESOURCES} doesn't exist, there are no resources to apply" 1>&2
  exit 1
fi

STORE_CONFIGMAP_FILE="${CLUSTER_RESOURCES}/configmap-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}.yaml"
STORE_DEPLOYMENT_FILE="${CLUSTER_RESOURCES}/deployment-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}.yaml"
SSH_KEY_LOCATION="${SSH_PUB_KEY_LOCATION%.pub}"

# CLUSTER_NAME="${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}-${CLUSTER_NUM}"
# LOCATION=$(gcloud container clusters list --filter=${CLUSTER_NAME} --format="value(LOCATION)" )
# gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${LOCATION}

# Running ssh normally is missing the KUBECONFIG=/var/kubeconfig/kubeconfig environment variable

# Create a NS 'store'; using kubectl apply to make it idempotent 
ssh -T -i ${SSH_KEY_LOCATION} abm-admin@${HOST} "bash -l -c 'kubectl create ns store -o yaml --dry-run=client | kubectl apply -f -'"

# kubectl annotate serviceaccount -n store default iam.gke.io/gcp-service-account=${GCP_SA} --overwrite

cat ${STORE_CONFIGMAP_FILE} | ssh -i ${SSH_KEY_LOCATION} abm-admin@${HOST} "bash -l -c 'kubectl apply -f - -n store'"
cat ${STORE_DEPLOYMENT_FILE} | ssh -i ${SSH_KEY_LOCATION} abm-admin@${HOST} "bash -l -c 'kubectl apply -f - -n store'"
