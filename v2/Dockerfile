# Gallformers V2 - Multi-stage Dockerfile
# Builds Go API with embedded Svelte static files

# Stage 1: Build Svelte frontend
FROM node:20-alpine AS web-builder

WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci
COPY web/ .
RUN npm run build

# Stage 2: Build Go API
FROM golang:1.23-alpine AS api-builder
RUN apk add --no-cache gcc musl-dev git

WORKDIR /app

# Copy go.mod and go.sum first for better layer caching
COPY api/go.mod api/go.sum ./
RUN go mod download

# Copy API source code
COPY api/ .

# Copy built web static files to cmd/server/static for Go embedding
# (main.go uses //go:embed static/* which embeds from cmd/server/static/)
COPY --from=web-builder /app/web/build ./cmd/server/static

# Build with CGO enabled for SQLite
ARG VERSION=dev
RUN CGO_ENABLED=1 go build \
    -ldflags "-X main.Version=${VERSION} -X main.BuildDate=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o gallformers-api ./cmd/server

# Stage 3: Runtime
FROM alpine:3.19
RUN apk add --no-cache ca-certificates sqlite

# Install Litestream for continuous SQLite replication
ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.tar.gz /tmp/litestream.tar.gz
RUN tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz && rm /tmp/litestream.tar.gz

WORKDIR /app
COPY --from=api-builder /app/gallformers-api /app/gallformers-api
COPY litestream.yml /etc/litestream.yml

EXPOSE 8080
CMD ["litestream", "replicate", "-exec", "/app/gallformers-api"]
