# Stage 1: Builder
FROM python:3.10-slim as builder

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

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Set cache directories for model download
ENV XDG_CACHE_HOME=/app/.cache
ENV TRANSFORMERS_CACHE=/app/.cache/huggingface
ENV TORCH_HOME=/app/.cache/torch

# Copy downloader and pre-download models
COPY download_models.py .
RUN python download_models.py

# Copy application code
COPY . .
RUN mkdir -p uploads reports

# Generate internal SSL certs
RUN chmod +x generate_internal_certs.sh && ./generate_internal_certs.sh

# Stage 2: Runtime
FROM python:3.10-slim

# Install runtime system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    openssl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy everything from builder
COPY --from=builder /app /app
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Set persistent cache environment variables for runtime
ENV XDG_CACHE_HOME=/app/.cache
ENV TRANSFORMERS_CACHE=/app/.cache/huggingface
ENV TORCH_HOME=/app/.cache/torch

EXPOSE 8080

# Command to run the application (Instant startup as models are baked-in)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--ssl-keyfile", "/app/certs/internal.key", "--ssl-certfile", "/app/certs/internal.crt"]
