# =========================
# 1) Node build (Tailwind)
# =========================
FROM node:20-bookworm-slim AS nodebuilder
WORKDIR /app

# Install deps first (cache-friendly)
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build CSS
COPY . .
RUN npm run build:css

# =========================
# 2) PHP + Apache (Craft)
# =========================
FROM php:8.2-apache
WORKDIR /app

# System deps + PHP extensions Craft needs
RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" \
      pdo_mysql intl gd opcache zip bcmath \
  && rm -rf /var/lib/apt/lists/*

# Apache: enable rewrite + set docroot to /app/web
RUN a2enmod rewrite \
  && sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
  && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Composer binary
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy app code (includes composer.lock if it's in repo)
COPY . .

# Copy built CSS from node stage into final image
COPY --from=nodebuilder /app/web/assets/app.css /app/web/assets/app.css

# Install PHP deps (prod)
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Craft writable dirs
RUN mkdir -p storage runtime web/cpresources web/assets \
  && chown -R www-data:www-data storage runtime web/cpresources web/assets

# Railway: listen on $PORT
CMD ["bash","-lc","sed -ri \"s/Listen 80/Listen ${PORT}/\" /etc/apache2/ports.conf && apache2-foreground"]