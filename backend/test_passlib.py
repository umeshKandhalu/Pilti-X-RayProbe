from passlib.context import CryptContext
try:
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    print("Hashing 'password123'...")
    hashed = pwd_context.hash("password123")
    print(f"Hash: {hashed}")
    print("Verifying...")
    print(pwd_context.verify("password123", hashed))
except Exception as e:
    print(f"Error: {e}")
