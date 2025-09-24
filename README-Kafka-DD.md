🔹 1. Datadog Kafka Integration (Broker-level Monitoring)
    Use Datadog Agent + Kafka Integration
    Collects broker-level metrics via JMX.
    Monitors cluster health (lag, partitions, ISR, leader election, etc.).
    Not sufficient if you also want per-client app observability.

1. Docker Compose Environment
    Kafka + Zookeeper (Confluent image)
    Datadog Agent with APM + DogStatsD enabled
    Our Java client app (producer + consumer)
----------------    
🔹 2. Custom Java Kafka Client Instrumentation
    This automatically instruments:
        KafkaProducer send()
        KafkaConsumer poll()
        Traces message flows (with spans like kafka.produce, kafka.consume).
You’ll see distributed traces in Datadog if you propagate tracing headers.

    If you are writing a Java producer/consumer, you can integrate Datadog in two ways:
------------    
    (A) Using Datadog Java APM Tracer
    Add the Datadog Java agent to your JVM:
java -javaagent:/path/to/dd-java-agent.jar \
     -Ddd.service=kafka-client-app \
     -Ddd.env=dev \
     -Ddd.version=1.0 \
     -Ddd.logs.injection=true \
     -Ddd.trace.kafka.enabled=true \
     -jar my-kafka-client.jar
-----------
    (B) Expose Custom Metrics via Micrometer or Dropwizard
If you want business-level metrics (e.g., topic processing rate, consumer lag per app), instrument in code:
>> java:
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Counter;

public class KafkaConsumerApp {
    private final Counter messagesConsumed;

    public KafkaConsumerApp(MeterRegistry registry) {
        this.messagesConsumed = registry.counter("kafka.consumer.messages.consumed");
    }

    public void processMessage(String msg) {
        messagesConsumed.increment();
        // process logic
    }
}
## Then configure Datadog metrics exporter (Micrometer → Datadog) or push via DogStatsD:
>> java
import com.timgroup.statsd.NonBlockingStatsDClient;
import com.timgroup.statsd.StatsDClient;

StatsDClient statsd = new NonBlockingStatsDClient("kafka-client", "localhost", 8125);
statsd.incrementCounter("kafka.consumer.messages");
statsd.recordExecutionTime("kafka.consumer.latency", elapsedTime);
------
🔹 3. Consumer Lag & Topic-Level Monitoring

If your custom client is critical, you’ll also want consumer lag metrics:

Expose Kafka metrics: kafka.consumer.fetch.manager.records.lag.max

Or use Datadog’s Kafka Consumer integration with the agent running alongside your app.

🔹 4. Logs Correlation

Enable Datadog log injection (-Ddd.logs.injection=true).

Your Kafka client logs will include trace_id and span_id.

This lets you correlate Kafka messages → app traces → logs inside Datadog.

✅ Summary:
    Datadog has native Kafka integration for brokers.
    For Java custom clients, you can:
    Use the Datadog Java agent for automatic Kafka instrumentation.
    Push custom metrics via DogStatsD or Micrometer.
    Capture consumer lag and correlate logs with traces.

## docker-compose
version: "3.8"

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

  datadog:
    image: gcr.io/datadoghq/agent:latest
    environment:
      DD_API_KEY: ${DD_API_KEY}          # set in .env file
      DD_APM_ENABLED: "true"
      DD_DOGSTATSD_NON_LOCAL_TRAFFIC: "true"
      DD_LOGS_ENABLED: "true"
      DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL: "true"
    ports:
      - "8126:8126"   # APM
      - "8125:8125/udp" # DogStatsD
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

---------------
2. Maven pom.xml
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>kafka-datadog-sample</artifactId>
  <version>1.0.0</version>
  <properties>
    <java.version>17</java.version>
  </properties>
  <dependencies>
    <!-- Kafka client -->
    <dependency>
      <groupId>org.apache.kafka</groupId>
      <artifactId>kafka-clients</artifactId>
      <version>3.6.0</version>
    </dependency>

    <!-- Micrometer + Datadog -->
    <dependency>
      <groupId>io.micrometer</groupId>
      <artifactId>micrometer-registry-statsd</artifactId>
      <version>1.12.4</version>
    </dependency>

    <!-- Datadog Java tracer (runtime agent, optional dependency for compile) -->
    <dependency>
      <groupId>com.datadoghq</groupId>
      <artifactId>dd-trace-api</artifactId>
      <version>1.35.0</version>
    </dependency>
  </dependencies>
</project>
--------------------
3. Producer Example
import org.apache.kafka.clients.producer.*;
import java.util.Properties;

public class KafkaProducerApp {
    public static void main(String[] args) {
        Properties props = new Properties();
        props.put("bootstrap.servers", "kafka:9092");
        props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

        Producer<String, String> producer = new KafkaProducer<>(props);

        for (int i = 0; i < 10; i++) {
            String value = "Hello Datadog " + i;
            producer.send(new ProducerRecord<>("demo-topic", "key-" + i, value),
                (metadata, ex) -> {
                    if (ex == null) {
                        System.out.printf("Produced -> %s%n", value);
                    } else {
                        ex.printStackTrace();
                    }
                });
        }
        producer.close();
    }
}
------------
4. Consumer Example with Metrics
import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.serialization.StringDeserializer;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.statsd.StatsdConfig;
import io.micrometer.statsd.StatsdFlavor;
import io.micrometer.statsd.StatsdMeterRegistry;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class KafkaConsumerApp {
    public static void main(String[] args) {
        // Micrometer -> Datadog (DogStatsD)
        StatsdConfig config = new StatsdConfig() {
            @Override public String get(String k) { return null; }
            @Override public StatsdFlavor flavor() { return StatsdFlavor.DATADOG; }
            @Override public String host() { return "datadog"; }
            @Override public int port() { return 8125; }
        };
        MeterRegistry registry = new StatsdMeterRegistry(config, Clock.SYSTEM);
        var counter = registry.counter("kafka.consumer.messages.consumed");

        Properties props = new Properties();
        props.put("bootstrap.servers", "kafka:9092");
        props.put("group.id", "demo-consumer");
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", StringDeserializer.class.getName());

        KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
        consumer.subscribe(Collections.singletonList("demo-topic"));

        while (true) {
            ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(1000));
            for (ConsumerRecord<String, String> record : records) {
                System.out.printf("Consumed -> %s%n", record.value());
                counter.increment();
            }
        }
    }
}
--------------------
5. Run with Datadog Java Agent
>> bash
java -javaagent:/path/to/dd-java-agent.jar \
     -Ddd.service=kafka-client \
     -Ddd.env=dev \
     -Ddd.version=1.0 \
     -jar target/kafka-datadog-sample-1.0.0.jar

============================
Version 3  All dockerized
===========================
🏗 Full Setup: Kafka + Producer + Consumer + Datadog
1. Project Structure
version: "3.8"

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

  datadog:
    image: gcr.io/datadoghq/agent:latest
    environment:
      DD_API_KEY: ${DD_API_KEY}   # Put your API key in a .env file
      DD_APM_ENABLED: "true"
      DD_DOGSTATSD_NON_LOCAL_TRAFFIC: "true"
      DD_LOGS_ENABLED: "true"
      DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL: "true"
    ports:
      - "8126:8126"      # APM traces
      - "8125:8125/udp"  # DogStatsD metrics
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  producer:
    build: ./producer
    depends_on:
      - kafka
      - datadog
    environment:
      DD_AGENT_HOST: datadog
      DD_ENV: dev
      DD_SERVICE: kafka-producer
    command: >
      java -javaagent:/dd-java-agent.jar
           -Ddd.service=kafka-producer
           -Ddd.env=dev
           -Ddd.version=1.0
           -jar app.jar

  consumer:
    build: ./consumer
    depends_on:
      - kafka
      - datadog
    environment:
      DD_AGENT_HOST: datadog
      DD_ENV: dev
      DD_SERVICE: kafka-consumer
    command: >
      java -javaagent:/dd-java-agent.jar
           -Ddd.service=kafka-consumer
           -Ddd.env=dev
           -Ddd.version=1.0
           -jar app.jar
----------------           
## 3. Producer Dockerfile
FROM eclipse-temurin:17-jdk

WORKDIR /app
COPY target/producer-1.0.0.jar app.jar
ADD https://dtdg.co/latest-java-tracer dd-java-agent.jar

CMD ["java", "-jar", "app.jar"]
---------------
## 4. Consumer Dockerfile
FROM eclipse-temurin:17-jdk

WORKDIR /app
COPY target/consumer-1.0.0.jar app.jar
ADD https://dtdg.co/latest-java-tracer dd-java-agent.jar

CMD ["java", "-jar", "app.jar"]
-----------
5. Producer Code (KafkaProducerApp.java)

(same as before, produces messages to demo-topic)
Producer<String, String> producer = new KafkaProducer<>(props);
for (int i = 0; i < 10; i++) {
    String value = "Hello Datadog " + i;
    producer.send(new ProducerRecord<>("demo-topic", "key-" + i, value));
}
producer.close();
-------------
## 6. Consumer Code (KafkaConsumerApp.java)
(includes custom DogStatsD metrics via Micrometer)

StatsdConfig config = new StatsdConfig() {
    @Override public String get(String key) { return null; }
    @Override public StatsdFlavor flavor() { return StatsdFlavor.DATADOG; }
    @Override public String host() { return System.getenv("DD_AGENT_HOST"); }
    @Override public int port() { return 8125; }
};
MeterRegistry registry = new StatsdMeterRegistry(config, Clock.SYSTEM);
var counter = registry.counter("kafka.consumer.messages.consumed");
-----------------
## 7. Build & Run
# Build apps
mvn clean package

# Start everything
docker-compose up --build

--------------------
## Summary: ✅ What You’ll See in Datadog:
    - APM Traces: kafka.produce and kafka.consume spans
    - Custom Metrics: kafka.consumer.messages.consumed via DogStatsD
    - Logs (optional): correlated with traces if enabled
