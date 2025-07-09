# Usando PHP 8.2 com FPM (FastCGI Process Manager)
FROM php:8.2-fpm

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    libzip-dev \
    zip \
    unzip \
    nodejs \
    npm

# Instalar extensões PHP necessárias para Laravel
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# Instalar Composer (gerenciador de dependências PHP)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Criar usuário para evitar rodar como root
RUN groupadd -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Copiar código para dentro do container
COPY . /var/www
COPY --chown=www:www . /var/www

# Mudar para diretório de trabalho
WORKDIR /var/www

# Mudar para usuário www
USER www 