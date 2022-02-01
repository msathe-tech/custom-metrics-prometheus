# Overview
If you want to build this app refer to [this](application-overview-and-build.md).
If you want to use the existing image you can continue reading this doc. 

# Managed prometheus on GKE
Managed prometheus provided by Google Cloud allows users to setup a fully managed Prometheus monitoring pipeline on GKE and storage using Cloud Ops metrics storage. 
The Cloud Ops monitoring has a special explorer for managed promethes which gives you ability to explore the prometheus metrics using PromQL. 
Prometheus has become a standard for monitoring Kubernetes metrics. However, seting up scaling and maintaing the Promtheus is a challenge. Promtheus server also becomes a single point of failure. Moreover, the Prometheus is not designed for long-term metrics storage so you again have to find a way to sink the metrics in a long term time series storage which allows you to use and analyze the metrics. 
Managed Prometheus by Google Cloud is a designed to address these challenges while retaining the flexibility and standardization of Prometheus. 
In upcoming versions of GKE more out-of-box support will be provided so several of the steps listed in this doc will not be required in future versions of GKE. 

In this example we have a SpringBoot application that emits business metrics using Promtheus. The metrics are exposed using actuator endpoint. 

## Prereq
We assume you are in the correct K8s context and GCP project is set. 
It is important that you enable **Workload Identity** feature for the GKE during creation. 
Also, please enable **Cloud Monitoring** from the **Features** tab, and select **Workload** checkbox.

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
gcloud iam service-accounts create gmp-test-sa \
&&
gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:[your-gcp-project-id].svc.id.goog[gmp-test/default]" \
  gmp-test-sa@[your-gcp-project-id].iam.gserviceaccount.com \
&&
kubectl annotate serviceaccount \
  --namespace gmp-test \
  default \
  iam.gke.io/gcp-service-account=gmp-test-sa@[your-gcp-project-id].iam.gserviceaccount.com
```
Authorize the service account:
```
gcloud projects add-iam-policy-binding [your-gcp-project-id]\
  --member=serviceAccount:gmp-test-sa@[your-gcp-project-id].iam.gserviceaccount.com \
  --role=roles/monitoring.metricWriter
```


## Deploy the app along with scraping rule
Now deploy the app along with Pod Monitoring CR that contains the scraping location of the app.
```
kubectl apply -f k8s-yamls/cm.yaml -n gmp-test
kubectl apply -f k8s-yamls/deployment.yaml -n gmp-test
kubectl apply -f k8s-yamls/gke-pod-mon.yaml -n gmp-test
```
