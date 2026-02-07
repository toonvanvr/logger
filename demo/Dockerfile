FROM oven/bun:1.3.8

WORKDIR /workspace

# Copy shared and client packages (demo -> @logger/client -> @logger/shared)
COPY shared/ ./shared/
COPY client/ ./client/

# Install shared dependencies first (zod etc.)
WORKDIR /workspace/shared
RUN bun install

# Install client dependencies (resolves @logger/shared)
WORKDIR /workspace/client
RUN bun install

# Copy demo package files
COPY demo/package.json demo/tsconfig.json /workspace/demo/

# Install demo dependencies
WORKDIR /workspace/demo
RUN bun install

# Copy demo source (overridden by volume mount in development)
COPY demo/src/ ./src/

CMD ["bun", "run", "src/main.ts"]
