import pandas as pd
import json
import time
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=['kafka1:9092','kafka2:9093','kafka3:9094'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

df = pd.read_csv('/data/deliveries_500k.csv')

for row in df.to_dict(orient="records"):
    producer.send('deliveries', key=str(row['driver_id']).encode(), value=row)
    print(f"Sent: {row}")
    time.sleep(0.01)

producer.flush()
producer.close()