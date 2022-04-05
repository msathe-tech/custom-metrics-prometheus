# Overview
If you want to build this app refer to [this](application-overview-and-build.md).
If you want to use the existing image you can continue reading this doc. 

# Google Cloud Managed Service for Prometheus
[**Google Cloud Managed Service for Prometheus**](https://cloud.google.com/stackdriver/docs/managed-prometheus) allows users to setup a fully managed Prometheus monitoring pipeline on GKE and storage using Cloud Ops metrics storage. 
The Cloud Ops monitoring has a special explorer for managed Prometheus which gives you ability to explore the prometheus metrics using PromQL. 
Prometheus has become a standard for monitoring Kubernetes metrics. However, seting up scaling and maintaing the Prometheus is a challenge. Prometheus server also becomes a single point of failure. Moreover, the Prometheus is not designed for long-term metrics storage so you again have to find a way to sink the metrics in a long term time series storage which allows you to use and analyze the metrics. 
Google Cloud Managed Service for Prometheus is a designed to address these challenges while retaining the flexibility and standardization of Prometheus. 
Please check [GCP documentation](https://cloud.google.com/stackdriver/docs/managed-prometheus) for latest updates on this feature. 

In this example we have a SpringBoot application that emits business metrics using Prometheus. The metrics are exposed using actuator endpoint. 

## Prereq
We assume you are in the correct K8s context and GCP project is set. 
It is important that you enable **Workload Identity** feature for the GKE during creation. 
Also, please enable **Cloud Monitoring** from the **Features** tab.

## Setup the metrics pipeline
```
kubectl create ns gmp-test
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.1/manifests/setup.yaml

kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.1/manifests/operator.yaml
```

## Setup the service account for Workload Identity. 
Managed Service for Prometheus captures metric data by using the Cloud Monitoring API. If your cluster is using Workload Identity, you must grant your Kubernetes service account permission to the Monitoring API. 

Create and bind the service account: 
```
export PROJECT_ID=[your-gcp-project-id]
gcloud iam service-accounts create gmp-test-sa \
&&
gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[gmp-test/default]" \
  gmp-test-sa@${PROJECT_ID}.iam.gserviceaccount.com \
&&
kubectl annotate serviceaccount \
  --namespace gmp-test \
  default \
  iam.gke.io/gcp-service-account=gmp-test-sa@${PROJECT_ID}.iam.gserviceaccount.com
```
Authorize the service account:
```
gcloud projects add-iam-policy-binding ${PROJECT_ID}\
  --member=serviceAccount:gmp-test-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/monitoring.metricWriter
```
### Annotate SA in Kubernetes
If you already have setup GCP SA and policies are added to the SA then you only need to **annotate** SA in the Kubernetes.
```
kubectl annotate serviceaccount \
  --namespace gmp-test \
  default \
  iam.gke.io/gcp-service-account=gmp-test-sa@${PROJECT_ID}.iam.gserviceaccount.com
```


## Deploy the app along with scraping rule
Now deploy the app along with Pod Monitoring CR that contains the scraping location of the app.
```
kubectl apply -f k8s-yamls/cm.yaml -n gmp-test
kubectl apply -f k8s-yamls/deployment.yaml -n gmp-test
kubectl apply -f k8s-yamls/gke-pod-mon.yaml -n gmp-test
```

# Verify the custom metrics in Cloud Ops Monitoring
Navigate to Cloud Ops > Monitoring > Managed Prometheus.
In the PromQL Query section enter **Store_OrderQueue** and click Run Query.
![Custom Metrics](prometheus-app-metric.png?raw=true)

## Optional: add roles to stream application logs
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:gmp-test-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter" --no-user-output-enabled
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:gmp-test-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/stackdriver.resourceMetadata.writer" --no-user-output-enabled
```
