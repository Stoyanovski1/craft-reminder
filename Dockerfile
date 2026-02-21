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

RUN apt-get update && apt-get install -y \
    git unzip zip \
    libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libicu-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) gd intl pdo_mysql zip bcmath opcache \
  && rm -rf /var/lib/apt/lists/*

# Apache config (NO MPM changes)
RUN a2enmod rewrite headers \
  && sed -ri 's!/var/www/html!/app/web!g' /etc/apache2/sites-available/000-default.conf \
  && sed -ri 's!/var/www/!/app/!g' /etc/apache2/apache2.conf

# Copy whole project FIRST
COPY . /app

# Copy built CSS
COPY --from=nodebuilder /app/web/assets/app.css /app/web/assets/app.css

# Install composer AFTER full copy
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Writable folders
RUN mkdir -p storage runtime web/cpresources web/assets \
  && chown -R www-data:www-data storage runtime web/cpresources web/assets

CMD ["bash","-lc","sed -ri \"s/^Listen 80/Listen ${PORT}/\" /etc/apache2/ports.conf && apache2-foreground"]