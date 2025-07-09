#!/bin/bash
set -e

echo "🚀 Inicializando SIGAC Sistema..."

# Instalar dependências se não existirem
if [ ! -d "vendor" ]; then
    echo "📦 Instalando dependências PHP..."
    composer install --no-dev --optimize-autoloader
fi

# Copiar .env se não existir
if [ ! -f ".env" ]; then
    echo "⚙️  Copiando .env..."
    cp .env.example .env
fi

# Gerar chave se não existir
if ! grep -q "APP_KEY=" .env || [ "$(grep APP_KEY= .env | cut -d'=' -f2)" = "" ]; then
    echo "🔑 Gerando chave da aplicação..."
    php artisan key:generate
fi

# Aguardar banco estar disponível
echo "🔍 Aguardando banco de dados..."
while ! php artisan db:show >/dev/null 2>&1; do
    echo "⏳ Aguardando conexão com MySQL..."
    sleep 2
done

# Rodar migrações baseado no ambiente
echo "🗄️  Rodando migrações..."
if [ "$APP_ENV" = "production" ]; then
    # Em produção, apenas verifica se há migrações pendentes
    php artisan migrate:status || php artisan migrate --force
else
    # Em desenvolvimento, roda migrações sem --force
    php artisan migrate
fi

# Criar tabelas de sessão se não existirem (com verificação adequada)
echo "📝 Verificando tabela de sessões..."
if ! php artisan migrate:status | grep -q "sessions"; then
    echo "📝 Criando tabela de sessões..."
    php artisan session:table
    php artisan migrate
fi

# Limpar e cachear configurações apenas se não existir cache
echo "🧹 Verificando cache..."
if [ ! -f "bootstrap/cache/config.php" ]; then
    echo "🧹 Criando cache de configurações..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
else
    echo "✓ Cache já existe, pulando..."
fi

echo "✅ SIGAC inicializado com sucesso!"

# Iniciar PHP-FPM
exec php-fpm 