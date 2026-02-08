import bcrypt
import json
import io
from datetime import datetime
from storage import MinioStorage

storage = MinioStorage()

def verify_password(plain_password, hashed_password):
    """Verifies a plain password against a hashed one."""
    if isinstance(hashed_password, str):
        hashed_password = hashed_password.encode('utf-8')
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password)

def get_password_hash(password):
    """Hashes a password using bcrypt."""
    # Ensure password is truncated to 72 characters (bcrypt limit) to avoid errors
    password = password[:72]
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

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
                "created_at": datetime.now().isoformat()
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
