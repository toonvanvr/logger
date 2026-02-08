FROM oven/bun:1 AS base
WORKDIR /app

# Copy shared package (transitive dependency via client)
COPY packages/shared/ ./shared/

# Copy client package
COPY packages/client/ ./client/

# Copy sidecar package files
COPY packages/docker-sidecar/package.json ./docker-sidecar/
WORKDIR /app/docker-sidecar
RUN bun install

# Copy sidecar source
COPY packages/docker-sidecar/src/ ./src/

CMD ["bun", "run", "src/main.ts"]
