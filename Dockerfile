# Multi-stage build for optimized caching and smaller final image

# Stage 1: Composer dependencies
FROM composer:latest AS composer-stage
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --optimize-autoloader --ignore-platform-reqs

# Stage 2: Final PHP image
FROM php:8.2-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    libzip-dev \
    zip \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions including Redis
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl \
    && pecl install redis apcu \
    && docker-php-ext-enable redis apcu

# Copy OPcache configuration
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/php/local.ini /usr/local/etc/php/conf.d/local.ini

# Create user for Laravel application
RUN groupadd -g 1000 www \
    && useradd -u 1000 -ms /bin/bash -g www www

# Set working directory
WORKDIR /var/www

# Copy composer binary from composer stage
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy vendor directory from composer stage
COPY --from=composer-stage /app/vendor ./vendor

# Copy application code with correct ownership
COPY --chown=www:www . .

# Copy and set permissions for initialization script
COPY --chown=www:www scripts/init-laravel.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-laravel.sh

# Generate optimized autoloader
RUN composer dump-autoload --optimize --no-dev

# Set permanent permissions for storage and cache
RUN chown -R www-data:www-data storage/ bootstrap/cache/ \
    && chmod -R 755 storage/ bootstrap/cache/

# Switch to non-root user
USER www

# Expose port 9000 and start php-fpm
EXPOSE 9000
CMD ["/usr/local/bin/init-laravel.sh"] 