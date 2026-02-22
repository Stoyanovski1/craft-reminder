ARG CACHEBUST=6

############################
# 1) Build CSS (Node)
############################
FROM node:20-alpine AS assets

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY tailwind.config.js postcss.config.js ./
COPY src ./src
RUN npm run build:css


############################
# 2) PHP + Apache (Craft)
############################
FROM php:8.2-apache-bookworm

WORKDIR /app

# Enable needed Apache modules
RUN a2enmod rewrite headers

# ---- System deps + PHP extensions ----
RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd intl pdo_mysql zip bcmath opcache \
    && rm -rf /var/lib/apt/lists/*

# ---- Set Apache docroot to /app/web ----
RUN sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf

# ---- Install Composer ----
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ---- Copy app source ----
COPY . /app

# ---- Install PHP deps ----
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# ---- Copy built CSS from node stage ----
RUN mkdir -p /app/web/assets
COPY --from=assets /app/web/assets/app.css /app/web/assets/app.css

# ---- Writable dirs for Craft ----
RUN mkdir -p storage runtime web/cpresources web/assets \
    && chown -R www-data:www-data storage runtime web/cpresources web/assets

# ---- Runtime MPM Fix (runs every container start) ----
RUN printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'' \
'echo "==[DEBUG] mpm files BEFORE fix ==" ' \
'ls -la /etc/apache2/mods-enabled | grep mpm || true' \
'' \
'# Hard reset: remove any enabled MPM module symlinks' \
'rm -f /etc/apache2/mods-enabled/mpm_*.load /etc/apache2/mods-enabled/mpm_*.conf' \
'' \
'# Enable only prefork' \
'a2enmod mpm_prefork >/dev/null' \
'' \
'echo "==[DEBUG] mpm files AFTER fix ==" ' \
'ls -la /etc/apache2/mods-enabled | grep mpm || true' \
'' \
'exec apache2-foreground' \
> /usr/local/bin/start-apache && chmod +x /usr/local/bin/start-apache

EXPOSE 80
CMD ["/usr/local/bin/start-apache"]