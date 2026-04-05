@echo off

echo ===============================
echo Starting Kafka Pipeline (Ordered Execution)
echo ===============================

REM 1️⃣ Start Docker Compose
start "Docker Compose" cmd /k docker-compose up

echo Waiting for Kafka to be ready...

:wait_kafka
docker-compose exec kafka kafka-topics --list --bootstrap-server kafka:9092 >nul 2>&1

IF %ERRORLEVEL% NEQ 0 (
    echo Kafka not ready yet... retrying
    timeout /t 5 >nul
    goto wait_kafka
)

echo Kafka is ready!

REM 2️⃣ Create Topic
start "Create Topic" cmd /k docker-compose exec kafka kafka-topics --create --topic deliveries --bootstrap-server kafka:9092

timeout /t 3 >nul

REM 3️⃣ Start Consumer
start "Kafka Consumer" cmd /k docker-compose exec kafka kafka-console-consumer --topic deliveries --bootstrap-server kafka:9092 --from-beginning

timeout /t 3 >nul

REM 4️⃣ Start Spark
echo Starting Spark Streaming...
start "Spark Streaming" cmd /k docker-compose exec spark spark-submit --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 /app/analytics.py

REM 🧠 WAIT FOR SPARK TO INITIALIZE
echo Waiting for Spark to initialize...
timeout /t 15 >nul

REM 5️⃣ Start Producer (ONLY AFTER SPARK IS READY)
start "Producer" cmd /k docker-compose exec producer python /app/producer.py

echo ===============================
echo Full Pipeline Running!
echo ===============================

pause