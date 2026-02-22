# =========================
# 1) Build CSS (Tailwind)
# =========================
FROM node:20-alpine AS assets
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# kopiraj samo ono što treba za tailwind build
COPY tailwind.config.js postcss.config.js ./
COPY src ./src

# pravi web/assets/app.css
RUN npm run build:css


# =========================
# 2) PHP + Apache (Craft)
# =========================
FROM php:8.2-apache
WORKDIR /app

# System deps + PHP extensions for Craft
RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" \
        gd \
        intl \
        pdo_mysql \
        zip \
        bcmath \
        opcache \
  && rm -rf /var/lib/apt/lists/*

# Apache: ONLY prefork (avoid "More than one MPM loaded")
RUN a2dismod mpm_event mpm_worker || true \
 && a2enmod mpm_prefork \ 
 && a2enmod rewrite headers

# Set docroot to /app/web
RUN sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
 && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy app source (includes composer.lock)
COPY . /app

# Install PHP deps (requires composer.lock committed!)
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Copy built CSS into final image
RUN mkdir -p /app/web/assets
COPY --from=assets /app/web/assets/app.css /app/web/assets/app.css

# Writable dirs for Craft
RUN mkdir -p storage runtime web/cpresources web/assets \
 && chown -R www-data:www-data storage runtime web/cpresources web/assets

# Railway listens on $PORT
CMD ["bash","-lc","sed -ri \"s/^Listen 80$/Listen ${PORT}/\" /etc/apache2/ports.conf && apache2-foreground"]