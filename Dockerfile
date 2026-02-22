############################
# 1) Build frontend assets
############################
FROM node:20-alpine AS assets

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build


############################
# 2) PHP runtime (no Apache)
############################
FROM php:8.2-cli

RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install intl pdo_mysql zip gd opcache \
  && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Copy app
COPY . .

# Copy built frontend
COPY --from=assets /app/web /app/web

# Install PHP deps
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Writable dirs for Craft
RUN mkdir -p storage runtime web/cpresources web/assets \
  && chmod -R 777 storage runtime web/cpresources web/assets

CMD ["sh", "-c", "php -S 0.0.0.0:$PORT -t web"]