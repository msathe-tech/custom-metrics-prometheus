#!/usr/bin/env bash
# Copyright 2021 Google LLC
#
# This software is provided as-is, without warranty or representation for any use or purpose.
# Your use of it is subject to your agreement with Google.
#
# This script runs per store to generate the deployment and configmap for that store

set -e

# These must be set as environment variables or on the command line
# COUNTRY
# FRANCHISE_ID
# PROJECT_ID
# STORE_ID

usage() {
  {
    echo "$0 --country=[country] --franchise-id=[franchise_id] --store-id=[store_id] --cluster-num=[cluster_num]"
    echo "Or: COUNTRY=[country] FRANCHISE_ID=[franchise_id] STORE_ID=[store_id] $0"
    echo "-c,--country: Country store is located in. COUNTRY environment variable."
    echo "-f,--franchise,--franchise-id: Franchise store belongs to. FRANCHISE_ID environment variable."
    echo "-p,--project,--project-id: Project ID. PROJECT_ID environment variable."
    echo "-s,--store,--store-id: Store ID. STORE_ID environment variable."
    echo "-t,--tag: Docker image version tag. Defaults to v1."
  } 1>&2
}

TAG="v1"

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
    -p=* | --project=* | --project-id=*)
      PROJECT_ID="${i#*=}"
      shift
      ;;
    -s=* | --store=* | --store-id=*)
      STORE_ID="${i#*=}"
      shift
      ;;
    -t=* | --tag=*)
      TAG="${i#*=}"
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

if [[ -z "${STORE_ID}" ]]; then
  echo "Error: STORE_ID is not set" 1>&2
  ERROR=1
fi

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Error: PROJECT_ID is not set" 1>&2
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

if [[ ! -x "$(command -v sed)" ]]; then
  echo "Error: sed is required and not installed." 1>&2
  exit 1
fi

echo "Configuration:"
echo "COUNTRY: ${COUNTRY}"
echo "FRANCHISE_ID: ${FRANCHISE_ID}"
echo "STORE_ID: ${STORE_ID}"
echo "PROJECT_ID: ${PROJECT_ID}"
echo "TAG: ${TAG}"

# -- to handle directories starting with -
SCRIPT_DIR=$(dirname -- "$0")
CONFIG_DIR="${SCRIPT_DIR}/store-config"
STORE_FILE="store-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}.properties"
STORE_CONFIG="${CONFIG_DIR}/${STORE_FILE}"
FRANCHISE_FILE="franchise-${COUNTRY}-${FRANCHISE_ID}.properties"
FRANCHISE_CONFIG="${CONFIG_DIR}/${FRANCHISE_FILE}"
DEPLOYMENT_TEMPLATE="${SCRIPT_DIR}/deployment.template.yaml"

CLUSTER_RESOURCES="${SCRIPT_DIR}/cluster-resources/store-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}"

if [[ ! -d "${CLUSTER_RESOURCES}" ]]; then
  mkdir -p ${CLUSTER_RESOURCES}
fi

STORE_CONFIGMAP_FILE="${CLUSTER_RESOURCES}/configmap-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}.yaml"
STORE_DEPLOYMENT_FILE="${CLUSTER_RESOURCES}/deployment-${COUNTRY}-${FRANCHISE_ID}-${STORE_ID}.yaml"

# Generate config map
kubectl create configmap store-config --from-file=${STORE_CONFIG} --from-file=${FRANCHISE_CONFIG} -o yaml --dry-run=client > ${STORE_CONFIGMAP_FILE}

sed "s/{{ *STORE_PROPERTIES *}}/${STORE_FILE}/g;s/{{ *FRANCHISE_PROPERTIES *}}/${FRANCHISE_FILE}/g;s/{{ *PROJECT_ID *}}/${PROJECT_ID}/g;s/{{ *TAG *}}/${TAG}/g" ${DEPLOYMENT_TEMPLATE} > ${STORE_DEPLOYMENT_FILE}
