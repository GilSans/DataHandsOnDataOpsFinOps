"""
EMR Serverless Job - CSV to Parquet Conversion
"""
import sys
from pyspark.sql import SparkSession

def main():
    if len(sys.argv) != 3:
        print("Usage: emr_csv_to_parquet.py <input_path> <output_path>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    spark = SparkSession.builder.appName("CSV to Parquet").getOrCreate()

    print(f"Reading CSV from: {input_path}")
    df = spark.read.option("header", "true").option("inferSchema", "true").csv(input_path)

    print(f"Records: {df.count()}")
    df.printSchema()

    print(f"Writing Parquet to: {output_path}")
    df.write.mode("overwrite").parquet(output_path)

    print("Job completed!")
    spark.stop()

if __name__ == "__main__":
    main()
