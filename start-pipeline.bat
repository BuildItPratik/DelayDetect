@echo off

echo ===============================
echo Starting Kafka Pipeline (Ordered Execution)
echo ===============================

REM 1️⃣ Start Docker Compose
start "Docker Compose" cmd /k docker-compose up

REM 🔁 Wait for kafka1 container to exist
:wait_container
docker ps | findstr kafka1 >nul 2>&1

IF %ERRORLEVEL% NEQ 0 (
    echo Waiting for kafka1 container to start...
    timeout /t 3 >nul
    goto wait_container
)

echo kafka1 container started!

REM 🔁 Wait for Kafka broker to be ready
:wait_kafka
docker-compose exec kafka1 kafka-broker-api-versions --bootstrap-server kafka1:9092 >nul 2>&1

IF %ERRORLEVEL% NEQ 0 (
    echo Kafka not ready yet... retrying
    timeout /t 5 >nul
    goto wait_kafka
)

echo Kafka is ready!

REM 2️⃣ Delete topic (if exists)
docker-compose exec kafka1 kafka-topics --delete --topic deliveries --bootstrap-server kafka1:9092 >nul 2>&1

REM 🔁 Wait for topic deletion to complete
:wait_delete
docker-compose exec kafka1 kafka-topics --list --bootstrap-server kafka1:9092 | findstr deliveries >nul

IF %ERRORLEVEL% EQU 0 (
    echo Waiting for topic deletion...
    timeout /t 3 >nul
    goto wait_delete
)

echo Old topic cleared!

REM 3️⃣ Create Topic (replicated)
start "Create Topic" cmd /k docker-compose exec kafka1 kafka-topics --create ^
--if-not-exists ^
--topic deliveries ^
--bootstrap-server kafka1:9092 ^
--replication-factor 3 ^
--partitions 3

timeout /t 3 >nul

REM 4️⃣ Start Consumer
start "Kafka Consumer" cmd /k docker-compose exec kafka1 kafka-console-consumer ^
--topic deliveries ^
--bootstrap-server kafka1:9092 ^
--from-beginning

timeout /t 3 >nul

REM 5️⃣ Start Spark
echo Starting Spark Streaming...
start "Spark Streaming" cmd /k docker-compose exec spark spark-submit ^
--packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 ^
/app/analytics.py

REM 🧠 WAIT FOR SPARK TO INITIALIZE
echo Waiting for Spark to initialize...
timeout /t 15 >nul

REM 6️⃣ Start Producer
start "Producer" cmd /k docker-compose exec producer python /app/producer.py

echo ===============================
echo Full Pipeline Running!
echo ===============================

pause