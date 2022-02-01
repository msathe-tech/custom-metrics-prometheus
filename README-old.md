# Overview 
This application demonstrates custom metrics and logs emitted by Spring Boot application.
For custom metrics we are using Micrometer integration. 
We will emit 3 types of metrics - counter, gauge and timer. 

To run the application locally and specify the country, franchise ID, and store ID:
```
COUNTRY=usa FRANCHISE_ID=123 STORE_ID=1 ./mvnw spring-boot:run
```

You can also use env variable 
```
export COUNTRY=usa
export FRANCHISE_ID=123
export STORE_ID=1
./mvnw spring-boot:run
```

Naming convention for franchise YAML
```
franchise-$COUNTRY-$FRANCHISE_ID.yaml
```

Naming convention for store YAML
```
store-$COUNTRY-$FRANCHISE_ID-$STORE_ID.yaml
```

To add a new franchise say 9999 with store 99 create two files
```
store-usa-9999-99.properties
franchise-usa-9999.properties
```

To create a store configuration:

cd k8s
COUNTRY=usa FRANCHISE_ID=234 STORE_ID=2 ./render.sh -t=v3

To deploy the app to GKE:
cd k8s
COUNTRY=usa FRANCHISE_ID=123 STORE_ID=1 CLUSTER_NUM=1 ./apply.sh

To deploy the app to CNUC:

cd k8s
./cnuc-apply.sh -c=USA -f=123 -s=1 -p=cnuc-anthos-quest -h=34.74.212.144

Access the metrics using [Host]:[Port]/actuator/prometheus/. 
For local access use localhost:8080. 

### Metrics
This application emits following metrics to demonstrate performance of a hypothetical restaurant. 

* *Order* (counter) - Order number 
* *CurrentOrders* (gauge) - Current pending orders 
* *OrderProcessedTime* (timer) - Order processing time
* *LastOrderProcessedTime* (gauge) - Order processing time for the last order

### Logs

Logs are emitted in the following format - 
* UUID = [UUID]
* Store-OrderNumber = [order-counter]
* Order started - Time = [start-time hh:mm]
* Order started - Time = [finish-time hh:mm]
  
```
2021-05-04 06:41:36.391 INFO 1 --- [ scheduling-1] ricsPrometheusApplication$MetricsEmitter : UUID = 9ef79409-f821-417e-bd4a-54ebd9ac1029
Info
2021-05-04 02:41:33.392 EDT
Order finished - Time = 06:41
Info
2021-05-04 02:41:33.392 EDT
Order started - Time = 06:36
Info
2021-05-04 02:41:33.392 EDT
Store-OrderNumber = 756.0
Info
2021-05-04 02:41:33.392 EDT
2021-05-04 06:41:33.391 INFO 1 --- [ scheduling-1] ricsPrometheusApplication$MetricsEmitter : UUID = ae27781a-ebda-4716-816d-b75b935509a9
Info
2021-05-04 02:41:30.392 EDT
Order finished - Time = 06:41
Info
2021-05-04 02:41:30.392 EDT
Order started - Time = 06:37
Info
2021-05-04 02:41:30.392 EDT
Store-OrderNumber = 755.0
Info
2021-05-04 02:41:30.392 EDT
```

### Create container 
Login to gcloud and then 
```
PROJECT_ID=[your-project-id]
gcloud builds submit ./  --tag=gcr.io/$PROJECT_ID/custom-metrics-prometheus:v[n]
```
You can use Dockerhub to publish the image. 
**Please note** you will need to add ```docker-username``` and ```docker-password``` secrets in the secrets manager. 
```
gcloud builds submit ./ --config cloud-build-steps.yaml
```

You can also create container using [Cloud Native Buildpacks](https://buildpacks.io/). 
Following commands shows how to use build-image option command in spring-boot. 
```
REGISTRY_HOST=gcr.io
./mvnw spring-boot:build-image -DskipTests -Dspring-boot.build-image.imageName=$REGISTRY_HOST/$PROJECT_ID/custom-metrics-prometheus:latest
```

### Create service account for Prometheus (GKE only)
PROJECT_ID=anthos-quest
./k8s/create-sa.sh
