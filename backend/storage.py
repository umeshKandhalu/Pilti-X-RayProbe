import boto3
from botocore.exceptions import ClientError
import os
from dotenv import load_dotenv

load_dotenv()

class MinioStorage:
    def __init__(self):
        self.endpoint = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
        self.access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
        self.secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")
        self.bucket_name = os.getenv("MINIO_BUCKET_NAME", "pcss-data")
        self.secure = os.getenv("MINIO_SECURE", "False").lower() == "true"

        try:
            self.s3_client = boto3.client(
                's3',
                endpoint_url=self.endpoint,
                aws_access_key_id=self.access_key,
                aws_secret_access_key=self.secret_key,
                use_ssl=self.secure
            )
            self._ensure_bucket_exists()
        except Exception as e:
            print(f"Failed to initialize MinIO client: {e}")
            self.s3_client = None

    def _ensure_bucket_exists(self):
        if not self.s3_client: return
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
        except ClientError:
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
                print(f"Created bucket: {self.bucket_name}")
            except Exception as e:
                print(f"Error creating bucket: {e}")

    def upload_file(self, file_data, object_name, content_type):
        """Uploads a file-like object or bytes to MinIO."""
        if not self.s3_client:
            print("MinIO client not initialized. Skipping upload.")
            return False

        try:
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=object_name,
                Body=file_data,
                ContentType=content_type
            )
            print(f"Uploaded {object_name} to {self.bucket_name}")
            return True
        except Exception as e:
            print(f"Failed to upload {object_name}: {e}")
            return False

    def list_files(self, prefix):
        """Lists files with the given prefix."""
        if not self.s3_client: return []
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            return response.get('Contents', [])
        except Exception as e:
            print(f"Error listing files: {e}")
            return []

    def get_file(self, object_name):
        """Retrieves a file object from MinIO."""
        if not self.s3_client: return None
        try:
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=object_name)
            return response['Body'].read()
        except Exception as e:
            print(f"Error getting file {object_name}: {e}")
            return None
