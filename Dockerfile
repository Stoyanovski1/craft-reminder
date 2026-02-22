ARG CACHEBUST=1

############################
# 1) Build CSS (Node)
############################
FROM node:20-alpine AS assets

WORKDIR /app

# Install deps
COPY package.json package-lock.json ./
RUN npm ci

# Copy only what Tailwind needs
COPY tailwind.config.js postcss.config.js ./
COPY src ./src

# Build CSS -> web/assets/app.css
RUN npm run build:css



############################
# 2) PHP + Apache (Craft)
############################
FROM php:8.2-apache-bookworm

RUN set -eux; \
  # prvo disable sve (nije bitno ako neki ne postoje)
  a2dismod mpm_event mpm_worker mpm_prefork || true; \
  \
  # onda OBRIŠI sve mpm symlinkove da ne ostanu "duhovi"
  rm -f /etc/apache2/mods-enabled/mpm_*.load /etc/apache2/mods-enabled/mpm_*.conf; \
  \
  # uključi isključivo prefork
  a2enmod mpm_prefork; \
  \
  # sanity check: mora da ostane samo prefork
  apache2ctl -M | grep mpm

WORKDIR /app

# ---- FIX MPM CONFLICT ----
# Disable event/worker, enable prefork only
RUN a2dismod mpm_event mpm_worker || true \
    && a2enmod mpm_prefork

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
        gd \
        intl \
        pdo_mysql \
        zip \
        bcmath \
        opcache \
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

EXPOSE 80

CMD ["apache2-foreground"]