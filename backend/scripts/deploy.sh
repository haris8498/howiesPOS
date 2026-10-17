#!/usr/bin/env bash
# ===================================================
# Hungry Howie's POS - Automated Production Deployment
# ===================================================
set -euo pipefail

echo "🚀 Starting Production Deployment for Hungry Howie's POS Backend..."

# 1. Pull latest verified changes
echo "📥 Fetching latest code..."
git pull origin main

# 2. Install production dependencies
echo "📦 Installing clean production dependencies..."
npm ci

# 3. Generate Prisma client
echo "🔄 Generating Prisma ORM Client..."
npx prisma generate

# 4. Apply Prisma Migrations safely
echo "🗄️ Applying pending database migrations..."
npx prisma migrate deploy

# 5. Build production bundle
echo "🏗️ Building NestJS production distribution..."
npm run build

# 6. Reload process manager
if command -v pm2 &> /dev/null; then
  echo "🔁 Reloading PM2 process cluster..."
  pm2 reload ecosystem.config.js --env production || pm2 start ecosystem.config.js --env production
elif [ -f docker-compose.prod.yml ]; then
  echo "🐳 Rebuilding and restarting Docker containers..."
  docker compose -f docker-compose.prod.yml up -d --build
fi

# 7. Smoke check health probe
echo "🩺 Verifying health endpoint..."
sleep 3
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health || true)

if [ "${HEALTH_STATUS}" == "200" ]; then
  echo "✅ Deployment Successful! API is healthy (HTTP 200)."
else
  echo "⚠️ Warning: Health probe returned HTTP ${HEALTH_STATUS}. Please inspect logs."
fi
