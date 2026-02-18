# Stage 1: Build the Flutter Web App
FROM ubuntu:20.04 AS build-env

# Install dependencies for Flutter
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone -b stable https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run doctor to download dependencies
RUN flutter doctor -v

# Copy app files
WORKDIR /app
COPY . .

# Build for web
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Install gettext for envsubst
RUN apk add --no-cache gettext

# Copy built web assets to Nginx html directory
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Copy nginx configuration template
COPY nginx.conf.template /etc/nginx/conf.d/nginx.conf.template

# Default backend URL (internal docker network)
ENV BACKEND_URL=http://backend:8080

# Expose port (default for Nginx is 80)
EXPOSE 80

# Injection of environment variable at runtime
CMD ["/bin/sh", "-c", "envsubst '$BACKEND_URL' < /etc/nginx/conf.d/nginx.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
