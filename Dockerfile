# =========================
# 1) Build CSS (Tailwind)
# =========================
FROM node:20-alpine AS assets
WORKDIR /app

# Install deps
COPY package.json package-lock.json ./
RUN npm ci

# Build assets
COPY . .
RUN npm run build:css


# =========================
# 2) PHP + Apache (Craft)
# =========================
FROM php:8.2-apache
WORKDIR /app

# System deps + PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" gd intl pdo_mysql zip opcache \
  && rm -rf /var/lib/apt/lists/*

# Apache: enable rewrite + set docroot to /app/web (Craft)
RUN a2enmod rewrite \
 && sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
 && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install PHP deps (requires composer.lock in repo)
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Copy app source
COPY . .

# Copy built CSS into final image (overwrites whatever is in repo)
COPY --from=assets /app/web/assets/app.css /app/web/assets/app.css

# Ensure writable dirs for Craft
RUN mkdir -p storage runtime web/cpresources web/assets \
 && chown -R www-data:www-data storage runtime web/cpresources web/assets

# Railway uses $PORT
CMD ["bash","-lc","sed -ri \"s/^Listen 80/Listen ${PORT}/\" /etc/apache2/ports.conf && apache2-foreground"]