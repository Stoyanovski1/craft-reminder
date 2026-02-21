# =========================
# 1) Node build stage (Tailwind -> web/assets/app.css)
# =========================
FROM node:20-alpine AS assets

WORKDIR /app

# Copy only package files first (better caching)
COPY package.json package-lock.json* ./
RUN npm ci

# Copy the rest of the project (so Tailwind can scan templates/config)
COPY . .

# Build CSS (uses your package.json script build:css)
RUN npm run build:css


# =========================
# 2) PHP runtime stage (Craft CMS)
# =========================
FROM php:8.2-cli

WORKDIR /app

# System deps + PHP extensions Craft often needs
RUN apt-get update && apt-get install -y \
    unzip \
    libicu-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libzip-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install gd intl pdo_mysql zip opcache \
  && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy app code
COPY . .

# Copy built CSS from node stage (THIS FIXES 404)
RUN mkdir -p web/assets
COPY --from=assets /app/web/assets/app.css /app/web/assets/app.css
# Optional (only if generated)
# COPY --from=assets /app/web/assets/app.css.map /app/web/assets/app.css.map

# Runtime storage permissions
RUN mkdir -p storage/runtime storage/logs web/cpresources \
  && chmod -R 777 storage web/cpresources

# Install PHP deps (prod)
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Railway provides PORT
CMD ["sh", "-lc", "php -S 0.0.0.0:${PORT} -t web web/index.php"]