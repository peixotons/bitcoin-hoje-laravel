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

# Rodar migrações
echo "🗄️  Rodando migrações..."
php artisan migrate --force

# Criar tabelas de sessão se não existirem
echo "📝 Criando tabela de sessões..."
php artisan session:table 2>/dev/null || true
php artisan migrate --force

# Limpar e cachear configurações
echo "🧹 Otimizando cache..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "✅ SIGAC inicializado com sucesso!"

# Iniciar PHP-FPM
exec php-fpm 