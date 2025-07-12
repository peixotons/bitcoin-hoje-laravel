#!/bin/bash
set -e

echo "🚀 Bitcoin Hoje - Setup Automatizado"
echo "========================================"

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado. Por favor, instale o Docker primeiro."
    exit 1
fi

# Verificar se Docker Compose está instalado
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose não está instalado. Por favor, instale o Docker Compose primeiro."
    exit 1
fi

echo "✅ Docker e Docker Compose estão instalados"

# Parar containers existentes se estiverem rodando
echo "🛑 Parando containers existentes..."
docker compose down --remove-orphans || true

# Limpar volumes se solicitado
if [ "$1" = "--fresh" ]; then
    echo "🧹 Limpando volumes (instalação limpa)..."
    docker compose down -v
    docker volume prune -f
fi

# Criar .env se não existir
if [ ! -f ".env" ]; then
    echo "⚙️  Criando arquivo .env..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        echo "❌ Arquivo .env.example não encontrado!"
        exit 1
    fi
else
    echo "✅ Arquivo .env já existe"
fi

# Verificar se APP_KEY está vazio
if ! grep -q "APP_KEY=" .env || [ "$(grep APP_KEY= .env | cut -d'=' -f2)" = "" ]; then
    echo "🔑 APP_KEY está vazio ou não existe. Será gerado automaticamente durante a inicialização."
fi

# Build e inicializar containers
echo "🏗️  Construindo e iniciando containers..."
docker compose up -d --build

# Aguardar containers estarem prontos
echo "⏳ Aguardando containers ficarem prontos..."
sleep 10

# Verificar se os containers estão rodando
echo "🔍 Verificando status dos containers..."
docker compose ps

# Verificar logs da aplicação
echo "📋 Verificando logs da aplicação..."
docker compose logs app --tail=20

# Verificar se a aplicação está respondendo
echo "🌐 Verificando se a aplicação está respondendo..."
if curl -f http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ Aplicação está respondendo em http://localhost:8000"
else
    echo "⚠️  Aplicação ainda não está respondendo. Verifique os logs:"
    echo "   docker compose logs app"
fi

echo ""
echo "🎉 Setup concluído!"
echo "================================"
echo "📱 Aplicação: http://localhost:8000"
echo "📧 MailHog: http://localhost:8025"
echo "🗄️  MySQL: localhost:3307"
echo "🔴 Redis: localhost:6380"
echo "⚡ Vite: http://localhost:5173"
echo ""
echo "📋 Comandos úteis:"
echo "  - Ver logs: docker compose logs app"
echo "  - Reiniciar: docker compose restart"
echo "  - Parar: docker compose down"
echo "  - Limpar tudo: docker compose down -v"
echo "" 