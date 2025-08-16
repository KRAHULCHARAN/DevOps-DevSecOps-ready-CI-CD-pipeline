# Multi-stage build for security and optimization
# Try alternative base images if node:18-alpine fails
FROM node:18-slim AS base

# Install security updates and create non-root user
RUN apt-get update && apt-get install -y --no-install-recommends \
    && groupadd -r nodejs -g 1001 \
    && useradd -r -g nodejs -u 1001 nodejs

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-slim AS production

# Install security updates
RUN apt-get update && apt-get install -y --no-install-recommends

# Create non-root user
RUN groupadd -r nodejs -g 1001 \
    && useradd -r -g nodejs -u 1001 nodejs

# Set working directory
WORKDIR /app

# Copy dependencies from base stage
COPY --from=base --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodejs:nodejs . .

# Create logs directory with proper permissions
RUN mkdir -p logs && chown -R nodejs:nodejs logs

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

# Start application
CMD ["node", "src/server.js"]
