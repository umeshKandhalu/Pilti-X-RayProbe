import json
import io
import os
from datetime import datetime
from app.services.storage import MinioStorage
from app.core.security import get_password_hash, verify_password

# Initialize storage once or per request? Per module is fine for now as it uses config.
storage = MinioStorage()

class AuthService:
    def __init__(self):
        self.storage = storage

    def get_user(self, email):
        """Retrieves user data from MinIO."""
        try:
            # User data stored at email/account.json
            data = self.storage.get_file(f"{email}/account.json")
            if data:
                return json.loads(data)
        except Exception as e:
            print(f"Error fetching user {email}: {e}")
        return None

    def create_user(self, email, password, dob):
        """Creates a new user in MinIO."""
        if self.get_user(email):
             return False, "User already exists"

        try:
            user_data = {
                "email": email,
                "dob": dob,
                "password_hash": get_password_hash(password),
                "created_at": datetime.now().isoformat(),
                "role": "user",
                "max_storage_bytes": 1024 * 1024 * 1024, # 1 GB default
                "max_runs_count": 100 # 100 runs default
            }
            
            # Convert dict to JSON bytes
            json_bytes = json.dumps(user_data).encode('utf-8')
            self.storage.upload_file(
                io.BytesIO(json_bytes),
                f"{email}/account.json",
                "application/json"
            )
            return True, "User created successfully"
        except Exception as e:
            print(f"Error creating user: {e}")
            return False, str(e)

    def get_usage(self, email):
        """Returns current usage stats and limits."""
        storage_used = self.storage.get_directory_size(f"{email}/")
        
        user = self.get_user(email)
        runs_used = user.get('ai_runs_count', 0) if user else 0
        
        # Default limits for older users (1GB / 100 runs)
        max_storage = user.get('max_storage_bytes', 1024 * 1024 * 1024) if user else 1024 * 1024 * 1024
        max_runs = user.get('max_runs_count', 100) if user else 100
        
        return {
            "storage_used_bytes": storage_used,
            "max_storage_bytes": max_storage,
            "runs_used_count": runs_used,
            "max_runs_count": max_runs,
            "role": user.get('role', 'user') if user else 'user'
        }

    def increment_runs(self, email):
        """Increments the AI run counter for a user."""
        user = self.get_user(email)
        if not user:
            return False
            
        current_runs = user.get('ai_runs_count', 0)
        user['ai_runs_count'] = current_runs + 1
        
        # Save back to storage
        try:
            json_bytes = json.dumps(user).encode('utf-8')
            self.storage.upload_file(
                io.BytesIO(json_bytes),
                f"{email}/account.json",
                "application/json"
            )
            return True
        except Exception as e:
            print(f"Error updating user stats: {e}")
            return False

    def list_all_users(self):
        """Lists all users by scanning MinIO prefixes or local directories."""
        users_list = []
        try:
            if self.storage.s3_client:
                # S3 listing
                objects = self.storage.s3_client.list_objects_v2(Bucket=self.storage.bucket_name, Delimiter='/')
                common_prefixes = objects.get('CommonPrefixes', [])
                emails = [p.get('Prefix', '').rstrip('/') for p in common_prefixes if p.get('Prefix')]
            else:
                # Local listing
                emails = []
                if os.path.exists(self.storage.local_storage_path):
                    emails = [d for d in os.listdir(self.storage.local_storage_path) 
                             if os.path.isdir(os.path.join(self.storage.local_storage_path, d))]

            for email in emails:
                if not email or email == "pcss-data": continue
                user = self.get_user(email)
                if user:
                    usage = self.get_usage(email)
                    users_list.append({
                        "email": email,
                        "role": user.get('role', 'user'),
                        "created_at": user.get('created_at', 'Unknown'),
                        "storage_used_bytes": usage['storage_used_bytes'],
                        "max_storage_bytes": usage['max_storage_bytes'],
                        "runs_used_count": usage['runs_used_count'],
                        "max_runs_count": usage['max_runs_count']
                    })
            return users_list
        except Exception as e:
            print(f"Error listing users: {e}")
            return []

    def update_user_limits(self, email, max_storage=None, max_runs=None):
        """Updates limits for a specific user, enforced with hard caps."""
        user = self.get_user(email)
        if not user:
            return False, "User not found"
            
        if max_storage is not None:
            # Hard cap at 5GB
            user['max_storage_bytes'] = min(max_storage, 5 * 1024 * 1024 * 1024)
        if max_runs is not None:
            # Hard cap at 1000 runs
            user['max_runs_count'] = min(max_runs, 1000)
            
        try:
            json_bytes = json.dumps(user).encode('utf-8')
            self.storage.upload_file(
                io.BytesIO(json_bytes),
                f"{email}/account.json",
                "application/json"
            )
            return True, "Limits updated"
        except Exception as e:
            return False, str(e)

    def check_limits(self, email):
        """Checks if user has exceeded their specific limits. Returns (bool, message)."""
        stats = self.get_usage(email)
        
        if stats['storage_used_bytes'] >= stats['max_storage_bytes']:
            return False, f"Storage limit exceeded ({stats['max_storage_bytes'] // (1024*1024)}MB)"
            
        if stats['runs_used_count'] >= stats['max_runs_count']:
            return False, f"AI Analysis run limit exceeded ({stats['max_runs_count']} runs)"
            
        return True, "Within limits"

    def authenticate_user(self, email, password, dob):
        """Authenticates a user against stored data."""
        user = self.get_user(email)
        if not user:
            return False, "User not found"
            
        try:
            if not verify_password(password, user['password_hash']):
                return False, "Invalid password"
        except Exception as e:
            print(f"Auth error: {e}")
            return False, "Authentication failed"
            
        # Verify DOB matches if provided (for extra security)
        if dob and user.get('dob') != dob:
            return False, "Date of Birth does not match records"

        return True, "Login successful"
