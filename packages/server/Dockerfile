FROM oven/bun:1.3.8

WORKDIR /workspace

# Copy shared package (server depends on @logger/shared via file:../shared)
COPY packages/shared/ ./shared/

# Copy server package files
COPY packages/server/package.json packages/server/tsconfig.json ./server/

# Install server dependencies
WORKDIR /workspace/server
RUN bun install

# Copy server source (overridden by volume mount in development)
COPY packages/server/src/ ./src/

EXPOSE 8080 8081/udp 8082

CMD ["bun", "run", "src/main.ts"]
