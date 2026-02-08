FROM oven/bun:1 AS base
WORKDIR /app

# Copy shared package (transitive dependency via client)
COPY shared/ ./shared/

# Copy client package
COPY client/ ./client/

# Copy sidecar package files
COPY docker-sidecar/package.json ./docker-sidecar/
WORKDIR /app/docker-sidecar
RUN bun install

# Copy sidecar source
COPY docker-sidecar/src/ ./src/

CMD ["bun", "run", "src/main.ts"]
