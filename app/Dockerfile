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

# Copy built web assets to Nginx html directory
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port (default for Nginx is 80)
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
