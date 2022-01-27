package com.example.custom_metrics_prometheus;

import org.apache.logging.slf4j.SLF4JLogger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.actuate.autoconfigure.metrics.MeterRegistryCustomizer;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.config.MeterFilter;

import java.math.RoundingMode;
import java.text.DecimalFormat;
import java.time.Duration;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

@SpringBootApplication
@RestController
@EnableScheduling
public class CustomMetricsPrometheusApplication {

	Logger logger = LoggerFactory.getLogger(CustomMetricsPrometheusApplication.class);	

	public static void main(String[] args) {
		SpringApplication.run(CustomMetricsPrometheusApplication.class, args);
	}

	@GetMapping("/") 
	public String hello() {
		return "hello world\n";
	}

	
	@Component
	@Configuration
	// @PropertySource(value = "classpath:store-${spring.profiles.active}.properties", ignoreResourceNotFound = true)
	// @PropertySource(value = "classpath:franchise-${spring.profiles.active}.properties", ignoreResourceNotFound = true)
	// @PropertySource(value = "file:/store-config/store-${spring.profiles.active}.properties", ignoreResourceNotFound = true)
	// @PropertySource(value = "file:/store-config/franchise-${spring.profiles.active}.properties", ignoreResourceNotFound = true)

	// Following the new naming convention for franchise and store properties 
	// franchise-$COUNTRY-$FRANCHISE_ID.yaml, store-$COUNTRY-$FRANCHISE_ID-$STORE_ID.yaml
	@PropertySource(value = "classpath:${FRANCHISE_PROPERTIES}", ignoreResourceNotFound = true)
	@PropertySource(value = "classpath:${STORE_PROPERTIES}", ignoreResourceNotFound = true)
	@PropertySource(value = "file:/store-config/${FRANCHISE_PROPERTIES}", ignoreResourceNotFound = true)
	@PropertySource(value = "file:/store-config/${STORE_PROPERTIES}", ignoreResourceNotFound = true)
	public class MetricsEmitter {
		Logger logger = LoggerFactory.getLogger(MetricsEmitter.class);	

		private final String ORDER = "Store-OrderNumber";
		private final String CURRENT_ORDERS = "Store-OrderQueue";
		private final String ORDER_PROCESSED_TIME = "Store-OrderProcessedTime";
		private final String LAST_ORDER_PROCESSED_TIME = "Store-LastOrderProcessedTime";
		private final int ORDER_QUEUE_UPPER_BOUND = 25;
		private final String ORDER_START_TIME_LABEL = "Last Order started - Time";
		private final String ORDER_FINISHED_TIME_LABEL = "Last Order finished - Time";
		private final String ORDER_PROCESSING_TIME_50TH_PERCENTILE_LABEL = "Order processing time - 50th percentile";
		private final String ORDER_PROCESSING_TIME_95TH_PERCENTILE_LABEL = "Order processing time - 95th percentile";

		private DecimalFormat df2 = new DecimalFormat("##.##");


		MeterRegistry mr;
		final Counter order;
		final AtomicInteger currentOrders;
		final AtomicInteger lastOrderProcessedTime;
		final Timer orderProcessedTime;

		private final Random orderRandom; 
		private final Random rangeRandom;

		//@Value("${Franchise.NAME:Family Foods LLC}")
		private String franchise;

		//@Value("${Franchise.STORE:store1}")
		private String store;

		//@Value("${Franchise.COUNTRY:USA}")
		private String country;

		//@Value("${Franchise.CITY:New York}")
		private String city;

		private String frachiseId;
		private String latitude;
		private String longitude;
		private String region;
		private String zip;

	

		@Bean
		MeterRegistryCustomizer<MeterRegistry> registryCustomizer() {
			
			logger.debug(store);
			return registry -> registry.config()
				.commonTags("store", store)
				.meterFilter(MeterFilter.acceptNameStartsWith("Store-"))
				//.meterFilter(MeterFilter.deny())
				;
		}

		// @Bean
		// MeterFilter meterFilter1() {
		// 	return MeterFilter
		// 		.acceptNameStartsWith("Store-");
		// }
		
		public MetricsEmitter(MeterRegistry  mr,
				@Value("${Franchise.STORE:1}") String store, 
				@Value("${Franchise.COUNTRY:USA}") String country,
				@Value("${Franchise.CITY:Chicago}") String city,
				@Value("${Franchise.NAME:McDonalds}") String franchise, 
				@Value("${Franchise.FRANCHISE_ID:1}") String frachiseId,
				@Value("${Franchise.REGION:Mid-West}") String region,
				@Value("${Franchise.ZIP:60610}") String zip, 
				@Value("${Franchise.LATITUDE:41.892502}") String latitude,
				@Value("${Franchise.LONGITUDE:-87.631279}") String longitude
				) {
			this.mr = mr;
			this.franchise = franchise;
			this.store = store;
			this.country = country;
			this.city = city;
			this.region = region;
			this.zip = zip;
			this.frachiseId = frachiseId;
			this.latitude = latitude;
			this.longitude = longitude;
			
			ArrayList<Tag> tags = new ArrayList<>();
			tags.add(Tag.of("franchise", franchise));
			tags.add(Tag.of("storeID", store));
			tags.add(Tag.of("country", country));
			tags.add(Tag.of("city", city));

			tags.add(Tag.of("franchiseID", frachiseId));
			tags.add(Tag.of("latitude", latitude));
			tags.add(Tag.of("longitude", longitude));
			tags.add(Tag.of("region", region));
			tags.add(Tag.of("zip", zip));

			Iterable<io.micrometer.core.instrument.Tag> iTags = tags;
			//order = mr.counter("McD_Order", "storeID", store, "country", country, "city", city);
			order = mr.counter(ORDER, iTags);
			currentOrders = mr.gauge(CURRENT_ORDERS,iTags, new AtomicInteger(0));
			// orderProcessedTime = mr.timer("McD_OrderProcessedTime", iTags);
			orderProcessedTime = Timer.builder(ORDER_PROCESSED_TIME)
					//.sla(Duration.ofMinutes(1), Duration.ofMinutes(2), Duration.ofMinutes(3), Duration.ofMinutes(4),
					//	Duration.ofMinutes(5), Duration.ofMinutes(6), Duration.ofMinutes(7))
					.publishPercentiles(0.5, 0.95)
					//.publishPercentileHistogram()	
					.tags(iTags)
					.register(mr);

			lastOrderProcessedTime = mr.gauge(LAST_ORDER_PROCESSED_TIME, iTags, new AtomicInteger(0));

			orderRandom = new Random();
			rangeRandom = new Random();

			df2.setRoundingMode(RoundingMode.HALF_UP);
		}

		@Scheduled(fixedRate = 15000, initialDelay = 3000)
		public void emitMetrics() {
			
			//logger.info("chill...");
			order.increment();
			int curretOrdersValue = getRandomNumberInRange(0, ORDER_QUEUE_UPPER_BOUND);
			//String logOrderInfo = curretOrdersValue + " -- "; 
			currentOrders.set(curretOrdersValue);
			int orderProcessedTimeValue = processOrder();
			
			//logger.info(logOrderInfo + orderProcessedTimeValue);
			lastOrderProcessedTime.set(orderProcessedTimeValue);
			orderProcessedTime
			.record(Duration.ofSeconds(orderProcessedTimeValue));


			String uuid = UUID.randomUUID().toString();
			LocalTime finishedTime = LocalTime.now();
			LocalTime startTime = finishedTime.minusSeconds(lastOrderProcessedTime.longValue());
			
			String logOrderEntry =	new StringBuilder("{Country=").append(country)
					.append(", Region=").append(region)
					.append(", Franchise=").append(franchise)
					.append(", Franchise_ID=").append(frachiseId)
					.append(", City=").append(city)
					.append(", ZIP=").append(zip)
					.append(", latitude=").append(latitude)
					.append(", longitude=").append(longitude)
					.append(", Store_ID=").append(store).append("}")
					.append("::UUID = ").append(uuid)
					.append("::").append(ORDER).append(" = ").append(order.count())
					.append("::").append(ORDER_START_TIME_LABEL).append(" = ").append(startTime.format(DateTimeFormatter.ofPattern("HH:mm")))
					.append("::").append(ORDER_FINISHED_TIME_LABEL).append(" = ").append(finishedTime.format(DateTimeFormatter.ofPattern("HH:mm")))
					.append("::").append(LAST_ORDER_PROCESSED_TIME).append(" (min) = ").append((int) orderProcessedTimeValue/60).append(":").append(orderProcessedTimeValue%60)
					.append("::").append(ORDER_PROCESSING_TIME_50TH_PERCENTILE_LABEL).append(" (min) = ").append(df2.format(orderProcessedTime.takeSnapshot().percentileValues()[0].value(TimeUnit.MINUTES)))
					.append("::").append(ORDER_PROCESSING_TIME_95TH_PERCENTILE_LABEL).append(" (min) = ").append(df2.format(orderProcessedTime.takeSnapshot().percentileValues()[1].value(TimeUnit.MINUTES)))
					.append("::").append(CURRENT_ORDERS).append(" = ").append(currentOrders.intValue())
					.toString();
			logger.info(logOrderEntry);		

			
		}

		private int getRandomNumberInRange(int min, int max) {
			if (min >= max) {
			  throw new IllegalArgumentException("max must be greater than min");
			}
		
			return rangeRandom.nextInt((max - min) + 1) + min;
		}

		private int processOrder() {
			double dOrderTime = orderRandom.nextGaussian() * 1.5 + getRandomNumberInRange(120, 400);
			int iOrderTime = (int) Math.round(dOrderTime);
			return iOrderTime;
		}

		
	}

}
