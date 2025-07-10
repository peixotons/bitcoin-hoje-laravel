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
echo "🗄️  Verificando e rodando migrações..."
if [ "$APP_ENV" = "production" ]; then
    # Em produção, verifica se há migrações pendentes antes de rodar
    if php artisan migrate:status >/dev/null 2>&1; then
        # Se o comando funciona, verifica se há migrações pendentes
        if php artisan migrate:status 2>/dev/null | grep -q "Pending"; then
            echo "🗄️  Migrações pendentes encontradas, aplicando..."
            php artisan migrate --force
        else
            echo "✓ Todas as migrações já foram aplicadas"
        fi
    else
        # Se migrate:status falha (ex: tabela de migrations não existe), tenta rodar migrations
        echo "🗄️  Inicializando sistema de migrações..."
        php artisan migrate --force
    fi
else
    # Em desenvolvimento, roda migrações sem --force
    php artisan migrate
fi

# Criar tabelas de sessão se não existirem (com verificação adequada)
echo "📝 Verificando tabela de sessões..."
# Verifica se a tabela sessions já existe no banco de dados
if php artisan tinker --execute="echo (Schema::hasTable('sessions') ? 'exists' : 'missing');" 2>/dev/null | grep -q "exists"; then
    echo "✓ Tabela de sessões já existe"
else
    # Verifica se o arquivo de migration de sessions existe
    if ! ls database/migrations/*_create_sessions_table.php >/dev/null 2>&1; then
        echo "📝 Criando migration de sessões..."
        php artisan session:table
    fi
    echo "📝 Aplicando migration de sessões..."
    php artisan migrate
fi

# Limpar e cachear configurações verificando cada cache individualmente
echo "🧹 Verificando e criando caches..."

# Verificar e criar cache de configuração
if [ ! -f "bootstrap/cache/config.php" ]; then
    echo "🧹 Criando cache de configurações..."
    php artisan config:cache
else
    echo "✓ Cache de configuração já existe"
fi

# Verificar e criar cache de rotas
if [ ! -f "bootstrap/cache/routes-v7.php" ]; then
    echo "🧹 Criando cache de rotas..."
    php artisan route:cache
else
    echo "✓ Cache de rotas já existe"
fi

# Verificar e criar cache de views
if [ ! -d "storage/framework/views" ] || [ -z "$(ls -A storage/framework/views 2>/dev/null)" ]; then
    echo "🧹 Criando cache de views..."
    php artisan view:cache
else
    echo "✓ Cache de views já existe"
fi

echo "✅ SIGAC inicializado com sucesso!"

# Iniciar PHP-FPM
exec php-fpm 