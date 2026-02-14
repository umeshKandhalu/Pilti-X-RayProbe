import boto3
from botocore.exceptions import ClientError
from app.core.config import settings
import os
import shutil
from datetime import datetime

class MinioStorage:
    def __init__(self):
        self.endpoint = settings.MINIO_ENDPOINT
        self.access_key = settings.MINIO_ACCESS_KEY
        self.secret_key = settings.MINIO_SECRET_KEY
        self.bucket_name = settings.MINIO_BUCKET_NAME
        self.secure = settings.MINIO_SECURE
        self.local_storage_path = "pcss-data" # Local fallback directory

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
            print(f"Falling back to local storage at {self.local_storage_path}")
            self.s3_client = None
            if not os.path.exists(self.local_storage_path):
                os.makedirs(self.local_storage_path)

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
        """Uploads a file-like object or bytes to MinIO or Local Storage."""
        if not self.s3_client:
            # Local Fallback
            try:
                full_path = os.path.join(self.local_storage_path, object_name)
                os.makedirs(os.path.dirname(full_path), exist_ok=True)
                
                # Check if file_data is bytes or file-like
                if hasattr(file_data, 'read'):
                     content = file_data.read()
                else:
                     content = file_data
                
                if isinstance(content, str):
                    mode = 'w'
                else:
                    mode = 'wb'
                    
                with open(full_path, mode) as f:
                    f.write(content)
                print(f"Saved locally: {full_path}")
                return True
            except Exception as e:
                print(f"Local save failed: {e}")
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
        if not self.s3_client:
            # Local Fallback
            results = []
            for root, dirs, files in os.walk(self.local_storage_path):
                for file in files:
                    rel_path = os.path.relpath(os.path.join(root, file), self.local_storage_path)
                    if rel_path.startswith(prefix):
                        results.append({
                            'Key': rel_path,
                            'LastModified': datetime.fromtimestamp(os.path.getmtime(os.path.join(root, file))),
                            'Size': os.path.getsize(os.path.join(root, file))
                        })
            return results

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
        """Retrieves a file object from MinIO or Local Storage."""
        if not self.s3_client:
             # Local Fallback
            try:
                full_path = os.path.join(self.local_storage_path, object_name)
                if os.path.exists(full_path):
                    with open(full_path, 'rb') as f:
                        return f.read()
            except Exception as e:
                print(f"Local read failed: {e}")
            return None

        try:
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=object_name)
            return response['Body'].read()
        except Exception as e:
            print(f"Error getting file {object_name}: {e}")
            return None
    def get_directory_size(self, prefix):
        """Calculates total size of objects with the given prefix in bytes."""
        if not self.s3_client:
            # Local Fallback
            total_size = 0
            try:
                for root, _, files in os.walk(self.local_storage_path):
                    for file in files:
                        file_path = os.path.join(root, file)
                        rel_path = os.path.relpath(file_path, self.local_storage_path)
                        if rel_path.startswith(prefix):
                            total_size += os.path.getsize(file_path)
            except Exception as e:
                print(f"Error calculating local size: {e}")
            return total_size

        try:
            total_size = 0
            paginator = self.s3_client.get_paginator('list_objects_v2')
            for page in paginator.paginate(Bucket=self.bucket_name, Prefix=prefix):
                for obj in page.get('Contents', []):
                    total_size += obj['Size']
            return total_size
        except Exception as e:
            print(f"Error calculating directory size: {e}")
            return 0
