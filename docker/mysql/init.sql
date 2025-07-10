-- Script de inicialização do MySQL
-- Este arquivo é executado automaticamente quando o container MySQL é criado

-- Criar database se não existir
CREATE DATABASE IF NOT EXISTS sigac_db;

-- Dar permissões ao usuário root
GRANT ALL PRIVILEGES ON sigac_db.* TO 'root'@'%';
FLUSH PRIVILEGES;

-- Log de inicialização
SELECT 'Database sigac_db criado com sucesso!' as message; 