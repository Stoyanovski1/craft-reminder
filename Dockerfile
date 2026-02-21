# =========================
# 1) Node stage (Tailwind -> web/assets/app.css)
# =========================
FROM node:20-alpine AS nodebuilder
WORKDIR /app

# Lockfile MUST exist (package-lock.json). If you don't have it, generate it with `npm install` and commit it.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build:css


# =========================
# 2) PHP + Apache stage (Craft CMS)
# =========================
FROM php:8.2-apache

WORKDIR /app

# System deps + PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libonig-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) \
    pdo_mysql intl gd opcache zip bcmath \
  && rm -rf /var/lib/apt/lists/*

# Apache: enable rewrite + set docroot to /app/web
RUN a2enmod rewrite \
  && sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
  && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Composer binary
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Composer deps (composer.lock MUST exist)
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# App code
COPY . .

# Copy built CSS from node stage
COPY --from=nodebuilder /app/web/assets/app.css /app/web/assets/app.css

# Craft writable dirs
RUN mkdir -p storage runtime web/cpresources web/assets \
  && chown -R www-data:www-data storage runtime web/cpresources web/assets

# Railway provides $PORT, so patch Apache at container start, then run
CMD ["bash","-lc","sed -ri \"s/^Listen .*/Listen ${PORT}/\" /etc/apache2/ports.conf && apache2-foreground"]