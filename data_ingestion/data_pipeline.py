import os
import pandas as pd
import sqlite3

conn = sqlite3.connect("olist.db")

data_folder = "."

for file in os.listdir(data_folder):
    if file.endswith(".csv"):
        table_name = file.replace(".csv", "")
        df = pd.read_csv(f"{data_folder}/{file}")
        df.to_sql(table_name, conn, if_exists="replace", index=False)
        print(f" Loaded {file} → table: {table_name}")

conn.close()
print("\n Database ready! Open olist.db in DB Browser")
