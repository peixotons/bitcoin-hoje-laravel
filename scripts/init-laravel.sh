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

# CONTRAMEDIDA 1: Garantir que APP_KEY seja gerado automaticamente
echo "🔑 Verificando chave da aplicação..."
if ! grep -q "APP_KEY=" .env; then
    echo "🔑 Adicionando linha APP_KEY no .env..."
    echo "APP_KEY=" >> .env
fi

# Verificar se APP_KEY está vazio e gerar se necessário
if [ "$(grep APP_KEY= .env | cut -d'=' -f2)" = "" ]; then
    echo "🔑 Gerando nova chave da aplicação..."
    # Gerar chave manualmente se php artisan key:generate falhar
    if ! php artisan key:generate; then
        echo "🔑 Método alternativo: gerando chave manualmente..."
        NEW_KEY=$(php artisan key:generate --show)
        sed -i "s/APP_KEY=/APP_KEY=$NEW_KEY/" .env
        echo "✅ Chave da aplicação gerada: $NEW_KEY"
    fi
else
    echo "✓ Chave da aplicação já existe"
fi

# CONTRAMEDIDA 2: Aguardar MySQL estar disponível e criar banco se necessário
echo "🔍 Aguardando MySQL estar disponível..."
max_attempts=30
attempts=0

while [ $attempts -lt $max_attempts ]; do
    if mysql -h${DB_HOST} -u${DB_USERNAME} -p${DB_PASSWORD} -e "SELECT 1" >/dev/null 2>&1; then
        echo "✅ MySQL está disponível!"
        break
    else
        echo "⏳ Aguardando MySQL... (tentativa $((attempts + 1))/$max_attempts)"
        sleep 2
        attempts=$((attempts + 1))
    fi
done

if [ $attempts -eq $max_attempts ]; then
    echo "❌ Erro: MySQL não ficou disponível após $max_attempts tentativas"
    exit 1
fi

# CONTRAMEDIDA 3: Criar banco de dados se não existir
echo "🗄️  Verificando se banco de dados existe..."
if ! mysql -h${DB_HOST} -u${DB_USERNAME} -p${DB_PASSWORD} -e "USE ${DB_DATABASE};" >/dev/null 2>&1; then
    echo "🗄️  Criando banco de dados ${DB_DATABASE}..."
    mysql -h${DB_HOST} -u${DB_USERNAME} -p${DB_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_DATABASE};"
    echo "✅ Banco de dados ${DB_DATABASE} criado com sucesso!"
else
    echo "✓ Banco de dados ${DB_DATABASE} já existe"
fi

# Aguardar Laravel conseguir conectar no banco
echo "🔍 Aguardando Laravel conectar no banco..."
while ! php artisan db:show >/dev/null 2>&1; do
    echo "⏳ Aguardando conexão com banco de dados..."
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