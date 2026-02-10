import bcrypt

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
