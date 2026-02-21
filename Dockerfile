# =========================
# 1) Node build stage (Tailwind -> web/assets/app.css)
# =========================
FROM node:20-alpine AS nodebuilder
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci || npm install

# kopieren alles (src, templates, config fajlovi)
COPY . .

# pravi web/assets/app.css
RUN npm run build:css


# =========================
# 2) PHP + Apache stage (Craft CMS)
# =========================
FROM php:8.2-apache
WORKDIR /app

# System deps + PHP extensions (intl needs libicu-dev, Craft needs bcmath)
RUN apt-get update && apt-get install -y \
    git unzip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libonig-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) \
    pdo_mysql intl gd opcache zip bcmath \
  && rm -rf /var/lib/apt/lists/*

# Apache: rewrite + document root auf /app/web
RUN a2enmod rewrite \
 && sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
 && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Apache hört auf Railway PORT (8080) zu
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
 && sed -i 's/:80/:8080/' /etc/apache2/sites-available/000-default.conf

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Composer install
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# App code
COPY . .

# CSS final
COPY --from=nodebuilder /app/web/assets/app.css /app/web/assets/app.css

# Permissions (Craft treba storage + runtime + cpresources)
RUN mkdir -p storage runtime web/cpresources web/assets \
 && chown -R www-data:www-data storage runtime web/cpresources web/assets

ENV PORT=8080
EXPOSE 8080
CMD ["apache2-foreground"]