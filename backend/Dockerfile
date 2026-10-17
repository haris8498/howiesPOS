# ===================================================
# Multi-Stage Dockerfile for Hungry Howie's POS Backend
# ===================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Install build dependencies
COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci

# Copy application source
COPY . .

# Generate Prisma Client & Compile TypeScript
RUN npx prisma generate
RUN npm run build

# Prune dev dependencies for production
RUN npm prune --production

# --- Stage 2: Production Runtime ---
FROM node:20-alpine AS runner

WORKDIR /usr/src/app

ENV NODE_ENV=production
ENV PORT=3000

# Security: Run as non-root user
USER node

# Copy built artifacts and production dependencies
COPY --chown=node:node --from=builder /usr/src/app/package*.json ./
COPY --chown=node:node --from=builder /usr/src/app/node_modules ./node_modules
COPY --chown=node:node --from=builder /usr/src/app/dist ./dist
COPY --chown=node:node --from=builder /usr/src/app/prisma ./prisma

EXPOSE 3000

CMD ["node", "dist/main"]
