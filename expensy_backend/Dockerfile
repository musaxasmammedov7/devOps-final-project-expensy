# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM --platform=linux/amd64 node:20-alpine AS builder

WORKDIR /app

# Install dependencies (production + dev for TypeScript compile)
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and compile TypeScript → dist/
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# Prune dev dependencies so only production deps remain
RUN npm prune --production

# ── Stage 2: runtime (distroless) ─────────────────────────────────────────────
FROM --platform=linux/amd64 gcr.io/distroless/nodejs20-debian12

WORKDIR /app

# Copy compiled output and production node_modules from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

EXPOSE 3000

# distroless nodejs image entrypoint expects the script path as CMD
CMD ["dist/server.js"]
