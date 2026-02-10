import requests
import hmac
import hashlib
import json
import time
from datetime import datetime

BASE_URL = "http://localhost:8888"
SECRET_KEY = "your-secret-key-change-in-production"

def sign_request(body: bytes):
    timestamp = str(int(time.time()))
    message = f"{timestamp}".encode() + body
    signature = hmac.new(
        SECRET_KEY.encode(),
        message,
        hashlib.sha256
    ).hexdigest()
    return signature, timestamp

def test_security():
    # 1. Register a new user
    email = f"test_{int(time.time())}@example.com"
    password = "password123"
    dob = "1990-01-01"
    
    print(f"Registering {email}...")
    resp = requests.post(f"{BASE_URL}/register", json={
        "email": email,
        "password": password,
        "dob": dob
    })
    print(f"Register: {resp.status_code} {resp.text}")
    assert resp.status_code == 200

    # 2. Login
    print("Logging in...")
    resp = requests.post(f"{BASE_URL}/login", json={
        "email": email,
        "password": password
    })
    print(f"Login: {resp.status_code} {resp.json()}")
    assert resp.status_code == 200
    token = resp.json()["access_token"]
    
    # 3. Test /analyze (Secured)
    print("Testing /analyze (Secured)...")
    
    # 3a. Success Case
    files = {'file': ('test.jpg', b'fakeimagebytes', 'image/jpeg')}
    # Sign empty body for multipart
    timestamp = str(int(time.time()))
    signature = hmac.new(
        SECRET_KEY.encode(),
        f"{timestamp}".encode() + b"", # Empty body
        hashlib.sha256
    ).hexdigest()
    
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Timestamp": timestamp,
        "X-Signature": signature
    }
    
    # Expect 400 (File must be image) or 500 (Model not loaded), but NOT 401/403
    # Actually, model might not be loaded if I didn't set it up, but auth should pass.
    # If auth fails, we get 401/403.
    resp = requests.post(f"{BASE_URL}/analyze", files=files, headers=headers)
    print(f"Analyze (Auth): {resp.status_code} {resp.text}")
    assert resp.status_code not in [401, 403]

    # 3b. No Token -> Should Fail 401
    print("Testing /analyze without token...")
    resp = requests.post(f"{BASE_URL}/analyze", files=files, headers={
        "X-Timestamp": timestamp,
        "X-Signature": signature
    })
    print(f"Analyze (No Token): {resp.status_code}")
    assert resp.status_code == 401

    # 3c. Invalid Signature -> Should Fail 403
    print("Testing /analyze with invalid signature...")
    resp = requests.post(f"{BASE_URL}/analyze", files=files, headers={
        "Authorization": f"Bearer {token}",
        "X-Timestamp": timestamp,
        "X-Signature": "invalid_signature"
    })
    print(f"Analyze (Bad Sig): {resp.status_code}")
    assert resp.status_code == 403

if __name__ == "__main__":
    try:
        test_security()
    except AssertionError as e:
        print(f"Test Failed: {e}")
    except Exception as e:
        print(f"Error: {e}")
