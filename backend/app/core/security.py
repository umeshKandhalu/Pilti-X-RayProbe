from datetime import datetime, timedelta
from typing import Optional
from jose import jwt, JWTError
from passlib.context import CryptContext
import hashlib
import hmac
import os
from fastapi import HTTPException, status

# Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str, credentials_exception):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        return email
    except JWTError:
        raise credentials_exception

def verify_hmac(request_body: bytes, signature: str, timestamp: str, secret: str):
    """
    Verifies the HMAC signature of a request.
    Signature = HMAC-SHA256(secret, timestamp + body)
    """
    try:
        # 1. Prevent Replay Attacks (10 minute window for large requests like report generation)
        req_timestamp = int(timestamp)
        now = int(datetime.utcnow().timestamp())
        if abs(now - req_timestamp) > 600:  # Increased from 300 to 600 seconds
            return False, "Request timestamp expired"

        # 2. Recompute Signature
        message = f"{timestamp}".encode() + request_body
        computed_signature = hmac.new(
            secret.encode(),
            message,
            hashlib.sha256
        ).hexdigest()

        # 3. Compare safely
        if hmac.compare_digest(computed_signature, signature):
            return True, "Valid"
        else:
            return False, "Invalid signature"
    except Exception as e:
        return False, f"Verification error: {str(e)}"
