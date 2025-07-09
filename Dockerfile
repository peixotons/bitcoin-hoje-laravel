# Use PHP 8.2 FPM
FROM php:8.2-fpm

# Instalar dependências do sistema e aplicar atualizações de segurança
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    libzip-dev \
    zip \
    unzip

# Limpar cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar extensões PHP incluindo Redis
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl

# Instalar Redis extension via PECL
RUN pecl install redis && docker-php-ext-enable redis

# Obter o Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copiar código da aplicação
COPY . /var/www
COPY --chown=www-data:www-data . /var/www

# Copiar script de inicialização
COPY --chown=www-data:www-data scripts/init-laravel.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-laravel.sh

# Definir diretório de trabalho
WORKDIR /var/www

# Instalar dependências do Composer
RUN composer install --no-dev --optimize-autoloader

# Corrigir permissões do Laravel - PERMANENTEMENTE (usando o usuário www-data padrão do PHP-FPM)
RUN chown -R www-data:www-data storage/ bootstrap/cache/
RUN chmod -R 755 storage/ bootstrap/cache/

# Expor porta 9000 e iniciar php-fpm
EXPOSE 9000
CMD ["/usr/local/bin/init-laravel.sh"] 