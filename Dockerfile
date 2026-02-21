########################################
# 1️⃣ Node build stage (Tailwind)
########################################
FROM node:20-alpine AS nodebuilder

WORKDIR /app

# Install node deps
COPY package.json package-lock.json* ./
RUN npm install

# Copy project files
COPY . .

# Build CSS
RUN npm run build:css


########################################
# 2️⃣ PHP runtime stage
########################################
FROM php:8.2-cli

WORKDIR /app

RUN apt-get update && apt-get install -y \
    unzip \
    zip \
    libzip-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libonig-dev \
    libicu-dev \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql intl gd opcache zip \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy whole project
COPY . .

# 🔥 OVO JE KLJUČNO — kopiramo built CSS iz node stage-a
COPY --from=nodebuilder /app/web/assets /app/web/assets

# Install PHP deps
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Permissions
RUN mkdir -p storage runtime web/cpresources \
 && chmod -R 777 storage runtime web/cpresources web/assets

# Railway port
CMD ["sh", "-c", "php -S 0.0.0.0:${PORT:-8000} -t web web/index.php"]