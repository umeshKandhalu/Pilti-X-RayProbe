#!/bin/sh
mkdir -p /app/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /app/certs/internal.key \
  -out /app/certs/internal.crt \
  -subj "/C=US/ST=State/L=City/O=Pilti/CN=backend"
