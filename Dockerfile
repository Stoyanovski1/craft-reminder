# 1) build frontend assets
FROM node:20-alpine AS assets
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# 2) PHP runtime
FROM php:8.2-cli
RUN apt-get update && apt-get install -y git unzip libicu-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install intl pdo_mysql zip gd opcache \
  && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY . .
COPY --from=assets /app/web /app/web

RUN mkdir -p storage/runtime storage/logs web/cpresources \
  && chmod -R 777 storage web/cpresources

RUN composer install --no-interaction --prefer-dist --optimize-autoloader
CMD ["sh","-lc","php -S 0.0.0.0:$PORT -t web"]