sqlpipe is a command-line tool that copies PostgreSQL tables to Amazon S3 as Parquet files. It moves data into a data lake without a full ETL platform.

sqlpipe connects to your database and reads each table in batches. It converts the batches to Parquet and writes them to your S3 bucket. It can copy a full table, or only the new rows after a watermark column. Run it once for a backfill, or on a schedule.

The configuration is one YAML file. You can keep this file in version control with your infrastructure code.
