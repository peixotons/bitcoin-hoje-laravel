# Docker Setup Analysis for SIGAC System

## 🐳 Docker Compose Analysis

### Current Configuration Review

#### 1. **Container Names** (Lines 7, 27, 44, 64, 72, 97)
- **Current**: Each service has a hardcoded container name
- **Impact if removed**: Docker will auto-generate names like `sigac_app_1`
- **Recommendation**: Keep if you need predictable names for scripts/debugging, remove for scaling

#### 2. **Port Mappings**
- **MySQL port 3307:3306** (Line 52)
  - **Impact if removed**: Can't connect to DB from host machine
  - **Recommendation**: Remove in production, keep for development debugging
  
- **Redis port 6380:6379** (Line 66)
  - **Impact if removed**: Can't connect to Redis from host machine
  - **Recommendation**: Remove in production, internal access only

#### 3. **Deploy Resource Limits** (Lines 86-92)
- **Current**: Only Node service has memory limits (512M/256M)
- **Impact if removed**: Node could consume unlimited memory
- **Recommendation**: Keep but add to other services:
  ```yaml
  app:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
  ```

#### 4. **Environment Variables in Node Service** (Lines 82-85)
- **CHOKIDAR_USEPOLLING & CHOKIDAR_INTERVAL**
  - **Impact if removed**: File watching might not work in some Docker environments
  - **Recommendation**: Keep only if you experience file watching issues

#### 5. **MailHog Service** (Lines 95-104)
- **Impact if removed**: No local email testing capability
- **Recommendation**: Remove for production, use env-based inclusion for dev

### 🔴 Critical Issues Found

1. **MySQL Healthcheck Password Mismatch** (Line 57)
   ```yaml
   # Current (WRONG):
   test: ["CMD", "mysql", "-u", "root", "-psecret", "-e", "SELECT 1"]
   
   # Should be:
   test: ["CMD", "mysql", "-u", "root", "-p${DB_PASSWORD}", "-e", "SELECT 1"]
   ```

2. **Node Service Inefficiency** (Line 78)
   - Runs `npm install` on every container start
   - **Better approach**: Use a startup script that checks if node_modules exists

### 🟡 Optimization Opportunities

1. **Add Resource Limits to All Services**
2. **Use .env for Development/Production Switching**
3. **Add Health Checks to More Services**

---

## 📦 Dockerfile Analysis

### Performance Issues

1. **No Multi-Stage Build**
   - **Current Impact**: Large image size with build tools
   - **Improvement**: Use multi-stage to separate build and runtime

2. **Layer Optimization**
   - **Current**: Multiple RUN commands create many layers
   - **Improvement**: Combine related commands

3. **Composer Install Timing Issue**
   - **Problem**: Running `composer install` during build conflicts with volume mounting
   - **Solution**: Move to init script or use build cache

### 🔴 Critical Issues

1. **User Permission Confusion** (Lines 28-29 vs 45-46)
   ```dockerfile
   # Creates 'www' user
   RUN useradd -u 1000 -ms /bin/bash -g www www
   
   # But sets permissions for 'www-data'
   RUN chown -R www-data:www-data storage/ bootstrap/cache/
   ```

2. **Missing Security Updates**
   ```dockerfile
   # Add after apt-get update:
   RUN apt-get upgrade -y
   ```

### Optimized Dockerfile Example
```dockerfile
# Stage 1: Dependencies
FROM php:8.2-fpm as dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    git curl libpng-dev libonig-dev libxml2-dev libicu-dev libzip-dev zip unzip \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl \
    && pecl install redis && docker-php-ext-enable redis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Stage 2: Application
FROM dependencies as app
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
WORKDIR /var/www

# Use www-data user (already exists)
COPY --chown=www-data:www-data . /var/www
COPY --chown=www-data:www-data scripts/init-laravel.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-laravel.sh

USER www-data
EXPOSE 9000
CMD ["/usr/local/bin/init-laravel.sh"]
```

---

## 🚀 init-laravel.sh Analysis

### 🔴 Critical Issues

1. **Error Handling for session:table** (Line 36)
   ```bash
   # Current (might fail):
   php artisan session:table 2>/dev/null || true
   
   # Better:
   if ! php artisan migrate:status | grep -q "sessions"; then
       php artisan session:table
   fi
   ```

2. **Force Flag on Migrations** (Line 32, 38)
   - **Risk**: Could run destructive migrations in production
   - **Solution**: Use environment detection

3. **Cache Commands on Every Start** (Lines 41-44)
   - **Issue**: Unnecessary overhead on container restart
   - **Solution**: Check if cache exists first

### 🟡 Performance Improvements

```bash
#!/bin/bash
set -e

echo "🚀 Inicializando SIGAC Sistema..."

# Function to wait for database
wait_for_db() {
    echo "🔍 Aguardando banco de dados..."
    until php artisan db:show >/dev/null 2>&1; do
        echo "⏳ Aguardando conexão com MySQL..."
        sleep 2
    done
}

# Install dependencies if needed
if [ ! -d "vendor" ] || [ ! -f "vendor/autoload.php" ]; then
    echo "📦 Instalando dependências PHP..."
    composer install --no-dev --optimize-autoloader
fi

# Setup environment
if [ ! -f ".env" ]; then
    echo "⚙️  Copiando .env..."
    cp .env.example .env
fi

# Generate key if needed
if ! grep -q "^APP_KEY=.\+$" .env; then
    echo "🔑 Gerando chave da aplicação..."
    php artisan key:generate
fi

# Wait for database
wait_for_db

# Run migrations based on environment
if [ "$APP_ENV" = "production" ]; then
    echo "🗄️  Verificando migrações pendentes..."
    php artisan migrate:status || php artisan migrate --force
else
    echo "🗄️  Rodando migrações (dev)..."
    php artisan migrate
fi

# Cache only if not cached
if [ ! -f "bootstrap/cache/config.php" ]; then
    echo "🧹 Criando cache..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

echo "✅ SIGAC inicializado com sucesso!"

# Start PHP-FPM
exec php-fpm
```

---

## 📋 Summary of Recommendations

### High Priority
1. Fix MySQL healthcheck password
2. Fix user permission consistency in Dockerfile
3. Improve error handling in init-laravel.sh

### Medium Priority
1. Implement multi-stage Docker build
2. Add resource limits to all services
3. Optimize Node service startup

### Low Priority
1. Remove unnecessary port mappings for production
2. Make MailHog conditional based on environment
3. Cache optimization in init script

### Environment-Based Configuration Example
```yaml
# docker-compose.override.yml (for development)
services:
  db:
    ports:
      - "3307:3306"
  
  redis:
    ports:
      - "6380:6379"
  
  mailhog:
    image: mailhog/mailhog
    # ... rest of mailhog config
```