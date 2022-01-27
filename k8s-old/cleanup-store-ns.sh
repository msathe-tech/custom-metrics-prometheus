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
# STORE_ID

usage() {
  {
    echo "$0 --country=[country] --franchise-id=[franchise_id] --store-id=[store_id] --cluster-num=[cludster_num]"
    echo "Or: COUNTRY=[country] FRANCHISE_ID=[franchise_id] STORE_ID=[store_id] CLUSTER_NUM=[cluster_num] $0"
    echo "-c,--country: Country store is located in. COUNTRY environment variable."
    echo "-f,--franchise,--franchise-id: Franchise store belongs to. FRANCHISE_ID environment variable."
    echo "-k,--cluster,--cluster-num: Kubernetes cluster number. CLUSTER_NUM environment variable."
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
    -k=* | --cluster=* | --cluster-num=* | --cluster-number=*)
      CLUSTER_NUM="${i#*=}"
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

if [[ -z "${CLUSTER_NUM}" ]]; then
  echo "Error: CLUSTER_NUM is not set" 1>&2
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

if [[ ! -x "$(command -v kubectl)" ]]; then
  echo "Error: kubectl is required and not installed." 1>&2
  exit 1
fi

if [[ ! -x "$(command -v gcloud)" ]]; then
  echo "Error: gcloud is required and not installed." 1>&2
  exit 1
fi 

echo "Configuration:"
echo "COUNTRY: ${COUNTRY}"
echo "FRANCHISE_ID: ${FRANCHISE_ID}"
echo "STORE_ID: ${STORE_ID}"
echo "CLUSTER_NUM: ${CLUSTER_NUM}"

# -- to handle directories starting with -
SCRIPT_DIR=$(dirname -- "$0")
CLUSTER_RESOURCES="${SCRIPT_DIR}/cluster-resources/store-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}"

if [[ ! -d ${CLUSTER_RESOURCES} ]]; then
  echo "Error: ${CLUSTER_RESOURCES} doesn't exist, there are no resources to apply" 1>&2
  exit 1
fi

STORE_CONFIGMAP_FILE="${CLUSTER_RESOURCES}/configmap-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}.yaml"
STORE_DEPLOYMENT_FILE="${CLUSTER_RESOURCES}/deployment-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}.yaml"
CLUSTER_NAME="${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}-${CLUSTER_NUM}"

LOCATION=$(gcloud container clusters list --filter=${CLUSTER_NAME} --format="value(LOCATION)" )

gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${LOCATION}

# Delete the store namespace and all its resources
kubectl delete ns store