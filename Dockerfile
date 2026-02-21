# =========================
# 1) Node build stage (Tailwind -> web/assets/app.css)
# =========================
FROM node:20-alpine AS assets

WORKDIR /app

# Copy only the files needed to install deps first (better caching)
COPY package.json package-lock.json ./
RUN npm ci

# Now copy the rest of the project (so Tailwind has templates/config)
COPY . .

# Build CSS (must create /web/assets/app.css)
RUN npm run build:css


# =========================
# 2) PHP runtime stage (Craft CMS)
# =========================
FROM php:8.2-cli

WORKDIR /app

# System deps + PHP extensions Craft often needs
RUN apt-get update && apt-get install -y \
  git unzip zip libzip-dev \
  libicu-dev \
  libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install pdo_mysql intl gd opcache zip \
  && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy app code
COPY . .

# Copy the built CSS from the node stage (overwrites if missing)
RUN mkdir -p web/assets \
  && cp -f /app/web/assets/app.css web/assets/app.css

# Install PHP deps (production)
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Permissions (Craft needs these writable)
RUN mkdir -p storage web/cpresources \
  && chmod -R 777 storage web/cpresources

# Railway provides PORT
CMD ["sh", "-lc", "php -S 0.0.0.0:${PORT:-8080} -t web web/index.php"]