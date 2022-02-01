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