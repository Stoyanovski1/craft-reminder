# =========================
# 1) Node stage (Tailwind)
# =========================
FROM node:20-bookworm-slim AS nodebuilder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build:css


# =========================
# 2) PHP + Apache stage (Craft CMS)
# =========================
FROM php:8.2-apache
WORKDIR /app

# System deps + PHP extensions (Craft needs)
RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" gd intl pdo_mysql zip bcmath opcache \
  && rm -rf /var/lib/apt/lists/*

# Apache: enable rewrite/headers + set docroot to /app/web (NO mpm changes!)
RUN a2enmod rewrite headers \
  && sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
  && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Composer binary
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install PHP deps from lock (must exist in repo)
COPY composer.json composer.lock /app/
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# App code
COPY . /app

# Copy built CSS from node stage (guarantee it exists)
COPY --from=nodebuilder /app/web/assets/app.css /app/web/assets/app.css

# Craft writable dirs
RUN mkdir -p storage runtime web/cpresources web/assets \
  && chown -R www-data:www-data storage runtime web/cpresources web/assets

# Railway uses $PORT
CMD ["bash","-lc","sed -ri \"s/^Listen 80/Listen ${PORT}/\" /etc/apache2/ports.conf && apache2-foreground"]