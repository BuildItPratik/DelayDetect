import pandas as pd
import json
import time
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=['kafka:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

df = pd.read_csv('/data/deliveries_500k.csv')

for row in df.to_dict(orient="records"):
    producer.send('deliveries', value=row)
    print(f"Sent: {row}")
    time.sleep(0.01)

producer.flush()
producer.close()