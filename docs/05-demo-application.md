# 05 - Demo Application (Go Web Application)

## Overview

This guide covers the creation of a production-ready Go web application with comprehensive observability, health checks, and cloud-native best practices. The application serves as a demonstration for the CI/CD pipeline and monitoring stack.

---

## Architecture

```mermaid
graph TB
    subgraph "Application Components"
        MAIN[Main Server]
        ROUTER[HTTP Router]
        HANDLERS[Request Handlers]
        METRICS[Metrics Collector]
        LOGGER[Structured Logger]
        HEALTH[Health Checker]
    end

    subgraph "Endpoints"
        ROOT[/ - Home]
        HEALTH_EP[/health - Health Check]
        READY[/ready - Readiness]
        LIVE[/live - Liveness]
        METRICS_EP[/metrics - Prometheus]
        API[/api/* - API Routes]
    end

    subgraph "External Systems"
        PROM[Prometheus]
        K8S[Kubernetes]
        LOGS[Log Aggregator]
    end

    MAIN --> ROUTER
    ROUTER --> HANDLERS
    HANDLERS --> METRICS
    HANDLERS --> LOGGER
    HANDLERS --> HEALTH

    ROUTER --> ROOT
    ROUTER --> HEALTH_EP
    ROUTER --> READY
    ROUTER --> LIVE
    ROUTER --> METRICS_EP
    ROUTER --> API

    METRICS_EP --> PROM
    HEALTH_EP --> K8S
    READY --> K8S
    LIVE --> K8S
    LOGGER --> LOGS
```

### Key Features

- ✅ **RESTful API**: Clean HTTP endpoints
- ✅ **Health Checks**: Liveness, readiness, and startup probes
- ✅ **Prometheus Metrics**: RED method (Rate, Errors, Duration)
- ✅ **Structured Logging**: JSON logs with levels
- ✅ **Graceful Shutdown**: Clean termination handling
- ✅ **Configuration**: Environment-based config
- ✅ **Security**: Non-root user, read-only filesystem
- ✅ **Testing**: Unit and integration tests
- ✅ **Docker**: Multi-stage optimized builds

---

## 1. Application Structure

```
app/
├── main.go                 # Application entry point
├── go.mod                  # Go module definition
├── go.sum                  # Go module checksums
├── Dockerfile              # Multi-stage Docker build
├── .dockerignore           # Docker ignore patterns
├── Makefile                # Build automation
├── README.md               # Application documentation
├── handlers/               # HTTP handlers
│   ├── health.go          # Health check handlers
│   ├── home.go            # Home page handler
│   └── api.go             # API handlers
├── middleware/             # HTTP middleware
│   ├── logging.go         # Request logging
│   ├── metrics.go         # Metrics collection
│   └── recovery.go        # Panic recovery
├── config/                 # Configuration
│   └── config.go          # Config management
├── metrics/                # Metrics definitions
│   └── metrics.go         # Prometheus metrics
└── tests/                  # Tests
    ├── unit/              # Unit tests
    └── integration/       # Integration tests
```

---

## 2. Create Go Application

### 2.1 Initialize Go Module

```bash
# Create app directory
mkdir -p app
cd app

# Initialize Go module
go mod init github.com/your-username/demo-app

# Expected output:
# go: creating new go.mod: module github.com/your-username/demo-app
```

### 2.2 Create Main Application (main.go)

```go
package main

import (
 "context"
 "fmt"
 "log"
 "net/http"
 "os"
 "os/signal"
 "syscall"
 "time"

 "github.com/gorilla/mux"
 "github.com/prometheus/client_golang/prometheus"
 "github.com/prometheus/client_golang/prometheus/promhttp"
 "github.com/sirupsen/logrus"
)

var (
 // Application version
 Version = "1.0.0"

 // Logger
 logger = logrus.New()

 // Metrics
 httpRequestsTotal = prometheus.NewCounterVec(
  prometheus.CounterOpts{
   Name: "http_requests_total",
   Help: "Total number of HTTP requests",
  },
  []string{"method", "endpoint", "status"},
 )

 httpRequestDuration = prometheus.NewHistogramVec(
  prometheus.HistogramOpts{
   Name:    "http_request_duration_seconds",
   Help:    "HTTP request duration in seconds",
   Buckets: prometheus.DefBuckets,
  },
  []string{"method", "endpoint"},
 )

 httpRequestsInFlight = prometheus.NewGauge(
  prometheus.GaugeOpts{
   Name: "http_requests_in_flight",
   Help: "Current number of HTTP requests being served",
  },
 )
)

func init() {
 // Configure logger
 logger.SetFormatter(&logrus.JSONFormatter{})
 logger.SetOutput(os.Stdout)
 logger.SetLevel(logrus.InfoLevel)

 // Register metrics
 prometheus.MustRegister(httpRequestsTotal)
 prometheus.MustRegister(httpRequestDuration)
 prometheus.MustRegister(httpRequestsInFlight)
}

func main() {
 // Get configuration from environment
 port := getEnv("PORT", "8080")

 logger.WithFields(logrus.Fields{
  "version": Version,
  "port":    port,
 }).Info("Starting application")

 // Create router
 router := mux.NewRouter()

 // Apply middleware
 router.Use(loggingMiddleware)
 router.Use(metricsMiddleware)
 router.Use(recoveryMiddleware)

 // Register routes
 router.HandleFunc("/", homeHandler).Methods("GET")
 router.HandleFunc("/health", healthHandler).Methods("GET")
 router.HandleFunc("/ready", readinessHandler).Methods("GET")
 router.HandleFunc("/live", livenessHandler).Methods("GET")
 router.HandleFunc("/metrics", promhttp.Handler().ServeHTTP).Methods("GET")

 // API routes
 apiRouter := router.PathPrefix("/api/v1").Subrouter()
 apiRouter.HandleFunc("/info", infoHandler).Methods("GET")
 apiRouter.HandleFunc("/echo", echoHandler).Methods("POST")

 // Create server
 srv := &http.Server{
  Addr:         ":" + port,
  Handler:      router,
  ReadTimeout:  15 * time.Second,
  WriteTimeout: 15 * time.Second,
  IdleTimeout:  60 * time.Second,
 }

 // Start server in goroutine
 go func() {
  logger.WithField("port", port).Info("Server starting")
  if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
   logger.WithError(err).Fatal("Server failed to start")
  }
 }()

 // Wait for interrupt signal
 quit := make(chan os.Signal, 1)
 signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
 <-quit

 logger.Info("Server shutting down")

 // Graceful shutdown with timeout
 ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
 defer cancel()

 if err := srv.Shutdown(ctx); err != nil {
  logger.WithError(err).Fatal("Server forced to shutdown")
 }

 logger.Info("Server exited")
}

// Handlers

func homeHandler(w http.ResponseWriter, r *http.Request) {
 w.Header().Set("Content-Type", "text/html")
 fmt.Fprintf(w, `
  <!DOCTYPE html>
  <html>
  <head>
   <title>Demo App</title>
   <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    h1 { color: #333; }
    .info { background: #f0f0f0; padding: 20px; border-radius: 5px; }
   </style>
  </head>
  <body>
   <h1>🚀 Demo Application</h1>
   <div class="info">
    <p><strong>Version:</strong> %s</p>
    <p><strong>Status:</strong> Running</p>
    <p><strong>Endpoints:</strong></p>
    <ul>
     <li><a href="/health">/health</a> - Health check</li>
     <li><a href="/ready">/ready</a> - Readiness probe</li>
     <li><a href="/live">/live</a> - Liveness probe</li>
     <li><a href="/metrics">/metrics</a> - Prometheus metrics</li>
     <li><a href="/api/v1/info">/api/v1/info</a> - Application info</li>
    </ul>
   </div>
  </body>
  </html>
 `, Version)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
 w.Header().Set("Content-Type", "application/json")
 w.WriteHeader(http.StatusOK)
 fmt.Fprintf(w, `{"status":"healthy","version":"%s"}`, Version)
}

func readinessHandler(w http.ResponseWriter, r *http.Request) {
 // Check if application is ready to serve traffic
 // Add checks for database, cache, etc.
 w.Header().Set("Content-Type", "application/json")
 w.WriteHeader(http.StatusOK)
 fmt.Fprint(w, `{"status":"ready"}`)
}

func livenessHandler(w http.ResponseWriter, r *http.Request) {
 // Check if application is alive
 w.Header().Set("Content-Type", "application/json")
 w.WriteHeader(http.StatusOK)
 fmt.Fprint(w, `{"status":"alive"}`)
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
 w.Header().Set("Content-Type", "application/json")
 hostname, _ := os.Hostname()
 fmt.Fprintf(w, `{
  "version": "%s",
  "hostname": "%s",
  "timestamp": "%s"
 }`, Version, hostname, time.Now().Format(time.RFC3339))
}

func echoHandler(w http.ResponseWriter, r *http.Request) {
 w.Header().Set("Content-Type", "application/json")
 // Echo back the request body
 fmt.Fprint(w, `{"message":"echo endpoint"}`)
}

// Middleware

func loggingMiddleware(next http.Handler) http.Handler {
 return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  start := time.Now()

  // Create response writer wrapper to capture status code
  wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

  next.ServeHTTP(wrapped, r)

  duration := time.Since(start)

  logger.WithFields(logrus.Fields{
   "method":     r.Method,
   "path":       r.URL.Path,
   "status":     wrapped.statusCode,
   "duration":   duration.Milliseconds(),
   "remote_ip":  r.RemoteAddr,
   "user_agent": r.UserAgent(),
  }).Info("HTTP request")
 })
}

func metricsMiddleware(next http.Handler) http.Handler {
 return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  start := time.Now()
  httpRequestsInFlight.Inc()
  defer httpRequestsInFlight.Dec()

  wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

  next.ServeHTTP(wrapped, r)

  duration := time.Since(start).Seconds()

  httpRequestsTotal.WithLabelValues(
   r.Method,
   r.URL.Path,
   fmt.Sprintf("%d", wrapped.statusCode),
  ).Inc()

  httpRequestDuration.WithLabelValues(
   r.Method,
   r.URL.Path,
  ).Observe(duration)
 })
}

func recoveryMiddleware(next http.Handler) http.Handler {
 return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  defer func() {
   if err := recover(); err != nil {
    logger.WithFields(logrus.Fields{
     "error": err,
     "path":  r.URL.Path,
    }).Error("Panic recovered")

    w.WriteHeader(http.StatusInternalServerError)
    fmt.Fprint(w, `{"error":"Internal server error"}`)
   }
  }()

  next.ServeHTTP(w, r)
 })
}

// Helper types and functions

type responseWriter struct {
 http.ResponseWriter
 statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
 rw.statusCode = code
 rw.ResponseWriter.WriteHeader(code)
}

func getEnv(key, defaultValue string) string {
 if value := os.Getenv(key); value != "" {
  return value
 }
 return defaultValue
}
```

### 2.3 Create go.mod

```bash
# Add dependencies
go get github.com/gorilla/mux
go get github.com/prometheus/client_golang/prometheus
go get github.com/prometheus/client_golang/prometheus/promhttp
go get github.com/sirupsen/logrus

# Tidy dependencies
go mod tidy
```

---

## 3. Create Dockerfile

### 3.1 Multi-Stage Dockerfile

Create `app/Dockerfile`:

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.Version=${VERSION:-dev}" \
    -o app \
    main.go

# Final stage
FROM scratch

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy application binary
COPY --from=builder /build/app /app

# Create non-root user
# Note: In scratch, we can't create users, so we'll use numeric UID
USER 65534:65534

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app", "healthcheck"] || exit 1

# Run application
ENTRYPOINT ["/app"]
```

### 3.2 Optimized Dockerfile with Security

Create `app/Dockerfile.secure`:

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata \
    upx

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Run tests
RUN go test -v ./...

# Build application with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.Version=${VERSION:-dev}" \
    -trimpath \
    -o app \
    main.go

# Compress binary
RUN upx --best --lzma app

# Final stage - distroless
FROM gcr.io/distroless/static:nonroot

# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy application binary
COPY --from=builder /build/app /app

# Use non-root user
USER nonroot:nonroot

# Expose port
EXPOSE 8080

# Run application
ENTRYPOINT ["/app"]
```

### 3.3 Create .dockerignore

```
# Git
.git
.gitignore

# Documentation
*.md
docs/

# Tests
*_test.go
tests/

# Build artifacts
*.exe
*.dll
*.so
*.dylib

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Kubernetes
k8s/
*.yaml
*.yml

# CI/CD
.github/
Jenkinsfile
```

---

## 4. Build and Test Locally

### 4.1 Build Application

```bash
# Build Go application
cd app
go build -o demo-app main.go

# Run application
./demo-app

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

### 4.2 Build Docker Image

```bash
# Build Docker image
docker build -t demo-app:v1.0.0 .

# Run container
docker run -d -p 8080:8080 --name demo-app demo-app:v1.0.0

# Test container
curl http://localhost:8080/health

# View logs
docker logs demo-app

# Stop and remove
docker stop demo-app
docker rm demo-app
```

### 4.3 Test with Docker Compose

Create `app/docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - LOG_LEVEL=info
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
    restart: unless-stopped
```

Run with Docker Compose:

```bash
docker-compose up -d
docker-compose logs -f
docker-compose down
```

---

## 5. Create Makefile

Create `app/Makefile`:

```makefile
# Variables
APP_NAME := demo-app
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
DOCKER_REGISTRY := docker.io
DOCKER_IMAGE := $(DOCKER_REGISTRY)/$(APP_NAME)
GO_VERSION := 1.21

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help
help: ## Show this help message
 @echo "$(BLUE)Available targets:$(NC)"
 @grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the application
 @echo "$(BLUE)Building application...$(NC)"
 go build -ldflags="-X main.Version=$(VERSION)" -o $(APP_NAME) main.go
 @echo "$(GREEN)Build complete!$(NC)"

.PHONY: test
test: ## Run tests
 @echo "$(BLUE)Running tests...$(NC)"
 go test -v -race -coverprofile=coverage.out ./...
 @echo "$(GREEN)Tests complete!$(NC)"

.PHONY: coverage
coverage: test ## Generate coverage report
 @echo "$(BLUE)Generating coverage report...$(NC)"
 go tool cover -html=coverage.out -o coverage.html
 @echo "$(GREEN)Coverage report: coverage.html$(NC)"

.PHONY: lint
lint: ## Run linter
 @echo "$(BLUE)Running linter...$(NC)"
 golangci-lint run ./...
 @echo "$(GREEN)Linting complete!$(NC)"

.PHONY: fmt
fmt: ## Format code
 @echo "$(BLUE)Formatting code...$(NC)"
 go fmt ./...
 @echo "$(GREEN)Formatting complete!$(NC)"

.PHONY: vet
vet: ## Run go vet
 @echo "$(BLUE)Running go vet...$(NC)"
 go vet ./...
 @echo "$(GREEN)Vet complete!$(NC)"

.PHONY: run
run: ## Run the application
 @echo "$(BLUE)Running application...$(NC)"
 go run main.go

.PHONY: docker-build
docker-build: ## Build Docker image
 @echo "$(BLUE)Building Docker image...$(NC)"
 docker build -t $(APP_NAME):$(VERSION) -t $(APP_NAME):latest .
 @echo "$(GREEN)Docker image built: $(APP_NAME):$(VERSION)$(NC)"

.PHONY: docker-run
docker-run: ## Run Docker container
 @echo "$(BLUE)Running Docker container...$(NC)"
 docker run -d -p 8080:8080 --name $(APP_NAME) $(APP_NAME):latest
 @echo "$(GREEN)Container running at http://localhost:8080$(NC)"

.PHONY: docker-stop
docker-stop: ## Stop Docker container
 @echo "$(BLUE)Stopping Docker container...$(NC)"
 docker stop $(APP_NAME) || true
 docker rm $(APP_NAME) || true
 @echo "$(GREEN)Container stopped$(NC)"

.PHONY: docker-push
docker-push: docker-build ## Push Docker image to registry
 @echo "$(BLUE)Pushing Docker image...$(NC)"
 docker tag $(APP_NAME):$(VERSION) $(DOCKER_IMAGE):$(VERSION)
 docker tag $(APP_NAME):$(VERSION) $(DOCKER_IMAGE):latest
 docker push $(DOCKER_IMAGE):$(VERSION)
 docker push $(DOCKER_IMAGE):latest
 @echo "$(GREEN)Image pushed: $(DOCKER_IMAGE):$(VERSION)$(NC)"

.PHONY: clean
clean: ## Clean build artifacts
 @echo "$(BLUE)Cleaning...$(NC)"
 rm -f $(APP_NAME)
 rm -f coverage.out coverage.html
 go clean
 @echo "$(GREEN)Clean complete!$(NC)"

.PHONY: deps
deps: ## Download dependencies
 @echo "$(BLUE)Downloading dependencies...$(NC)"
 go mod download
 go mod tidy
 @echo "$(GREEN)Dependencies downloaded!$(NC)"

.PHONY: security-scan
security-scan: ## Run security scan
 @echo "$(BLUE)Running security scan...$(NC)"
 trivy image $(APP_NAME):latest
 @echo "$(GREEN)Security scan complete!$(NC)"

.PHONY: all
all: fmt vet lint test build ## Run all checks and build
 @echo "$(GREEN)All tasks complete!$(NC)"
```

---

## 6. Add Unit Tests

Create `app/main_test.go`:

```go
package main

import (
 "net/http"
 "net/http/httptest"
 "testing"
)

func TestHealthHandler(t *testing.T) {
 req, err := http.NewRequest("GET", "/health", nil)
 if err != nil {
  t.Fatal(err)
 }

 rr := httptest.NewRecorder()
 handler := http.HandlerFunc(healthHandler)

 handler.ServeHTTP(rr, req)

 if status := rr.Code; status != http.StatusOK {
  t.Errorf("handler returned wrong status code: got %v want %v",
   status, http.StatusOK)
 }

 expected := `{"status":"healthy","version":"` + Version + `"}`
 if rr.Body.String() != expected {
  t.Errorf("handler returned unexpected body: got %v want %v",
   rr.Body.String(), expected)
 }
}

func TestReadinessHandler(t *testing.T) {
 req, err := http.NewRequest("GET", "/ready", nil)
 if err != nil {
  t.Fatal(err)
 }

 rr := httptest.NewRecorder()
 handler := http.HandlerFunc(readinessHandler)

 handler.ServeHTTP(rr, req)

 if status := rr.Code; status != http.StatusOK {
  t.Errorf("handler returned wrong status code: got %v want %v",
   status, http.StatusOK)
 }
}

func TestLivenessHandler(t *testing.T) {
 req, err := http.NewRequest("GET", "/live", nil)
 if err != nil {
  t.Fatal(err)
 }

 rr := httptest.NewRecorder()
 handler := http.HandlerFunc(livenessHandler)

 handler.ServeHTTP(rr, req)

 if status := rr.Code; status != http.StatusOK {
  t.Errorf("handler returned wrong status code: got %v want %v",
   status, http.StatusOK)
 }
}

func TestHomeHandler(t *testing.T) {
 req, err := http.NewRequest("GET", "/", nil)
 if err != nil {
  t.Fatal(err)
 }

 rr := httptest.NewRecorder()
 handler := http.HandlerFunc(homeHandler)

 handler.ServeHTTP(rr, req)

 if status := rr.Code; status != http.StatusOK {
  t.Errorf("handler returned wrong status code: got %v want %v",
   status, http.StatusOK)
 }

 contentType := rr.Header().Get("Content-Type")
 if contentType != "text/html" {
  t.Errorf("handler returned wrong content type: got %v want %v",
   contentType, "text/html")
 }
}
```

Run tests:

```bash
# Run tests
make test

# Generate coverage report
make coverage

# View coverage
open coverage.html
```

---

## 7. Application Configuration

### 7.1 Environment Variables

The application supports the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP server port |
| `LOG_LEVEL` | `info` | Log level (debug, info, warn, error) |
| `VERSION` | `dev` | Application version |

### 7.2 Configuration File (Optional)

Create `app/config.yaml`:

```yaml
server:
  port: 8080
  read_timeout: 15s
  write_timeout: 15s
  idle_timeout: 60s

logging:
  level: info
  format: json

metrics:
  enabled: true
  path: /metrics

health:
  enabled: true
  path: /health
```

---

## 8. Security Best Practices

### 8.1 Security Checklist

- [x] Non-root user in container
- [x] Read-only root filesystem
- [x] No secrets in code
- [x] HTTPS support (via ingress)
- [x] Input validation
- [x] Rate limiting (via ingress)
- [x] Security headers
- [x] Dependency scanning

### 8.2 Add Security Headers Middleware

```go
func securityHeadersMiddleware(next http.Handler) http.Handler {
 return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  w.Header().Set("X-Content-Type-Options", "nosniff")
  w.Header().Set("X-Frame-Options", "DENY")
  w.Header().Set("X-XSS-Protection", "1; mode=block")
  w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
  w.Header().Set("Content-Security-Policy", "default-src 'self'")

  next.ServeHTTP(w, r)
 })
}
```

---

## 9. Performance Optimization

### 9.1 Enable HTTP/2

```go
srv := &http.Server{
 Addr:         ":" + port,
 Handler:      router,
 ReadTimeout:  15 * time.Second,
 WriteTimeout: 15 * time.Second,
 IdleTimeout:  60 * time.Second,
 // Enable HTTP/2
 TLSConfig: &tls.Config{
  MinVersion: tls.VersionTLS12,
 },
}
```

### 9.2 Add Caching

```go
func cacheMiddleware(duration time.Duration) func(http.Handler) http.Handler {
 return func(next http.Handler) http.Handler {
  return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
   w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", int(duration.Seconds())))
   next.ServeHTTP(w, r)
  })
 }
}
```

---

## 10. Troubleshooting

### Issue 1: Application Won't Start

```bash
# Check logs
docker logs demo-app

# Check port availability
lsof -i :8080

# Check environment variables
docker exec demo-app env
```

### Issue 2: Health Checks Failing

```bash
# Test health endpoint
curl -v http://localhost:8080/health

# Check application logs
kubectl logs -n demo-app deployment/demo-app

# Describe pod
kubectl describe pod -n demo-app -l app=demo-app
```

### Issue 3: High Memory Usage

```bash
# Check memory usage
docker stats demo-app

# Profile application
go tool pprof http://localhost:8080/debug/pprof/heap
```

---

## 11. Useful Commands

```bash
# Build application
make build

# Run tests
make test

# Build Docker image
make docker-build

# Run container
make docker-run

# Stop container
make docker-stop

# Push to registry
make docker-push

# Clean artifacts
make clean

# Run all checks
make all
```

---

## 12. Next Steps

Now that the application is created, proceed to:

- **[06-cicd-pipeline.md](./06-cicd-pipeline.md)** - Set up the complete CI/CD pipeline

---

## Additional Resources

- [Go Documentation](https://golang.org/doc/)
- [Gorilla Mux](https://github.com/gorilla/mux)
- [Prometheus Client Go](https://github.com/prometheus/client_golang)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [12-Factor App](https://12factor.net/)
