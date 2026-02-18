FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    openssl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
# --no-cache-dir to keep image smaller
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Create directory for temporary uploads if needed
RUN mkdir -p uploads reports

# Expose port (Cloud Run expects 8080 by default, but we can config)
EXPOSE 8080

# Generate internal SSL certs and start app
COPY generate_internal_certs.sh .
RUN chmod +x generate_internal_certs.sh && ./generate_internal_certs.sh

# Command to run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--ssl-keyfile", "/app/certs/internal.key", "--ssl-certfile", "/app/certs/internal.crt"]
