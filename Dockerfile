############################
# 1) Node build stage
############################
FROM node:20-bookworm-slim AS nodebuilder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install

COPY . .
RUN npm run build:css


############################
# 2) PHP + Apache stage
############################
FROM php:8.2-apache

WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) gd intl pdo_mysql zip bcmath opcache \
  && rm -rf /var/lib/apt/lists/*

# Enable Apache mods + set docroot
RUN a2dismod mpm_event mpm_worker || true \
  && a2enmod mpm_prefork rewrite headers \
  && sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
  && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Copy full project first
COPY . /app

# Copy built CSS from node stage
COPY --from=nodebuilder /app/web/assets/app.css /app/web/assets/app.css

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Craft writable folders
RUN mkdir -p storage runtime web/cpresources web/assets \
  && chown -R www-data:www-data storage runtime web/cpresources web/assets

# Railway dynamic port
CMD ["bash","-lc","sed -ri \"s/^Listen 80/Listen ${PORT}/\" /etc/apache2/ports.conf && apache2-foreground"]