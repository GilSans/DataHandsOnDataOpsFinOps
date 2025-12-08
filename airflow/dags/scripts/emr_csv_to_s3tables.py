"""
EMR Serverless Job - CSV to S3 Tables (Iceberg)
"""
import sys
from pyspark.sql import SparkSession

def main():
    if len(sys.argv) != 5:
        print("Usage: emr_csv_to_s3tables.py <input_path> <s3_tables_bucket_arn> <namespace> <table>")
        sys.exit(1)

    input_path = sys.argv[1]
    s3_tables_bucket_arn = sys.argv[2]
    namespace = sys.argv[3]
    table = sys.argv[4]

    spark = SparkSession.builder \
        .appName("CSV to S3 Tables Iceberg") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.defaultCatalog", "s3tablesbucket") \
        .config("spark.sql.catalog.s3tablesbucket", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.s3tablesbucket.catalog-impl", "software.amazon.s3tables.iceberg.S3TablesCatalog") \
        .config("spark.sql.catalog.s3tablesbucket.warehouse", s3_tables_bucket_arn) \
        .getOrCreate()

    print(f"Reading CSV from: {input_path}")
    df = spark.read.option("header", "true").option("inferSchema", "true").csv(input_path)

    print(f"Records: {df.count()}")
    df.printSchema()

    spark.sql(f"CREATE NAMESPACE IF NOT EXISTS s3tablesbucket.{namespace}")

    table_name = f"s3tablesbucket.{namespace}.{table}"
    print(f"Writing to S3 Tables: {table_name}")

    df.writeTo(table_name).using("iceberg").createOrReplace()

    print("Job completed!")
    spark.stop()

if __name__ == "__main__":
    main()
