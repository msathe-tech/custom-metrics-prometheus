#!/bin/bash -e

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Error: PROJECT_ID is not set" 1>&2
  ERROR=1
fi

echo "This will create a Google Service Account and key that is used on each of the Target machines to run gcloud commands"

echo "PROJECT_ID: ${PROJECT_ID}"

GSA_NAME="prometheus-stackdriver"
GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

EXISTS=$(gcloud iam service-accounts list --filter="email=${GSA_EMAIL}" --format="value(name, disabled)" --project="${PROJECT_ID}")
if [[ -z "${EXISTS}" ]]; then
    # GSA does NOT exist, create
    gcloud iam service-accounts create ${GSA_NAME} \
        --description="Promtheus Stackdriver service account" \
        --display-name="Prometheus Stackdriver" \
        --project ${PROJECT_ID}
else
    if [[ "$EXISTS" =~ .*"disabled".* ]]; then
        # Found GSA is disabled, enable
        gcloud iam service-accounts enable ${GSA_EMAIL} --project ${PROJECT_ID}
    fi
    # otherwise, no need to do anything
fi

echo "Adding roles/logging.logWriter"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/logging.logWriter" --no-user-output-enabled

echo "Adding roles/monitoring.metricWriter"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/monitoring.metricWriter" --no-user-output-enabled

echo "Adding roles/stackdriver.resourceMetadata.writer"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/stackdriver.resourceMetadata.writer" --no-user-output-enabled
