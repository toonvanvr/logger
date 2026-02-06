FROM oven/bun:1.3.8

WORKDIR /app

# Copy package files
COPY package.json ./
COPY tsconfig.json ./

# Install dependencies
RUN bun install

# Copy source code (will be mounted as volume in development)
# COPY ../server ./server
