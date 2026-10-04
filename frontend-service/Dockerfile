# Stage 1: Build
FROM node:20-alpine AS builder
RUN apk upgrade --no-cache libcrypto3 libssl3
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production

# Stage 2: Runtime
FROM node:20-alpine
RUN apk upgrade --no-cache libcrypto3 libssl3
WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy production dependencies and app code with proper ownership
COPY --chown=appuser:appgroup --from=builder /app/node_modules ./node_modules
COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 3000
CMD ["npm", "start"]
