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
set RETRIES=0

:wait_kafka
set /a RETRIES+=1

IF %RETRIES% GTR 20 (
    echo Kafka failed to start!
    exit /b 1
)

docker-compose exec kafka1 kafka-topics --list --bootstrap-server kafka1:9092 >nul 2>&1

IF %ERRORLEVEL% NEQ 0 (
    echo Kafka not ready yet... retrying
    timeout /t 5 >nul
    goto wait_kafka
)

echo Kafka is ready!

REM 📁 Archive previous output
IF NOT EXIST archived mkdir archived

for /f %%i in ('powershell -command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set TS=%%i

set HAS_DATA=

IF EXIST output set HAS_DATA=1
IF EXIST checkpoints set HAS_DATA=1

IF DEFINED HAS_DATA (
    echo Archiving previous run...

    mkdir archived\run_%TS% >nul 2>&1

    IF EXIST output move output archived\run_%TS%\output >nul
    IF EXIST checkpoints move checkpoints archived\run_%TS%\checkpoints >nul
)

echo Creating fresh folders...
mkdir output >nul 2>&1
mkdir checkpoints >nul 2>&1

REM 2️⃣ Delete topic (non-blocking)
docker-compose exec kafka1 kafka-topics --delete ^
--topic deliveries ^
--bootstrap-server kafka1:9092 >nul 2>&1

echo Topic deletion requested (if it existed).

REM 3️⃣ Create Topic (separate terminal)
start "Create Topic" cmd /k docker-compose exec kafka1 kafka-topics --create ^
--if-not-exists ^
--topic deliveries ^
--bootstrap-server kafka1:9092 ^
--replication-factor 3 ^
--partitions 3

REM 🔁 Wait until topic exists
set RETRIES=0

:wait_topic
set /a RETRIES+=1

IF %RETRIES% GTR 15 (
    echo Topic creation failed!
    exit /b 1
)

docker-compose exec kafka1 kafka-topics --list --bootstrap-server kafka1:9092 | findstr deliveries >nul

IF %ERRORLEVEL% NEQ 0 (
    echo Waiting for topic to be created...
    timeout /t 3 >nul
    goto wait_topic
)

echo Topic 'deliveries' is ready!

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

REM Wait for Spark
echo Waiting for Spark to initialize...
timeout /t 15 >nul

REM 6️⃣ Start Producer
start "Producer" cmd /k docker-compose exec producer python /app/producer.py

echo ===============================
echo Full Pipeline Running!
echo ===============================

pause