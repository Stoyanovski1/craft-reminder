FROM php:8.2-cli

# System deps + PHP extensions needed by Craft
RUN apt-get update && apt-get install -y \
    git unzip libicu-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) intl pdo_mysql bcmath zip gd opcache \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . .

RUN mkdir -p storage/runtime storage/logs web/cpresources \
&& chmod -R 777 storage web/cpresources

RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Railway provides $PORT
CMD ["sh", "-lc", "php -S 0.0.0.0:${PORT} -t web web/index.php"]