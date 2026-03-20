# Demo Application

A production-ready Go web application demonstrating best practices for Kubernetes deployment with CI/CD.

## Features

- ✅ RESTful API with multiple endpoints
- ✅ Health check endpoints (liveness, readiness)
- ✅ Prometheus metrics exposure
- ✅ Structured logging with Zap
- ✅ Request ID tracking
- ✅ Graceful shutdown
- ✅ CORS support
- ✅ Panic recovery middleware
- ✅ Multi-stage Docker build
- ✅ Security best practices

## API Endpoints

### Health Checks
- `GET /health` - Overall health status
- `GET /health/ready` - Readiness probe (Kubernetes)
- `GET /health/live` - Liveness probe (Kubernetes)

### Metrics
- `GET /metrics` - Prometheus metrics

### Application
- `GET /` - Home endpoint with app info
- `GET /api/info` - Detailed application information
- `GET /api/version` - Version information
- `POST /api/echo` - Echo back JSON message

## Local Development

### Prerequisites
- Go 1.21+
- Docker (optional)

### Run Locally
```bash
cd demo-app
go mod download
go run cmd/server/main.go
```

### Build
```bash
go build -o bin/app cmd/server/main.go
```

### Run with Docker
```bash
docker build -t demo-app:latest .
docker run -p 8080:8080 demo-app:latest
```

## Configuration

Environment variables:
- `PORT` - Server port (default: 8080)
- `APP_NAME` - Application name (default: demo-app)
- `APP_VERSION` - Application version (default: 1.0.0)
- `ENVIRONMENT` - Environment (default: development)
- `LOG_LEVEL` - Log level (default: info)

## Testing

```bash
# Health check
curl http://localhost:8080/health

# Application info
curl http://localhost:8080/api/info

# Echo endpoint
curl -X POST http://localhost:8080/api/echo \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello, World!"}'

# Metrics
curl http://localhost:8080/metrics
```

## Project Structure

```
demo-app/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go            # Configuration management
│   ├── handlers/
│   │   └── handlers.go          # HTTP handlers
│   └── middleware/
│       └── middleware.go        # HTTP middleware
├── pkg/
│   └── health/
│       └── health.go            # Health check logic
├── deployments/
│   └── kubernetes/              # Kubernetes manifests
├── Dockerfile                   # Multi-stage Docker build
├── go.mod                       # Go module definition
└── README.md                    # This file
```

## Security Features

- Non-root user in container
- Minimal base image (scratch)
- Static binary compilation
- No shell in container
- Health checks
- Resource limits
- Read-only root filesystem support

## Kubernetes Deployment

See `deployments/kubernetes/` for Kubernetes manifests including:
- Deployment with resource limits
- Service
- ConfigMap
- Ingress
- ServiceMonitor (Prometheus)
- NetworkPolicy

## CI/CD

This application is designed to work with:
- Jenkins for CI (build, test, push)
- ArgoCD for CD (GitOps deployment)
- Prometheus for monitoring
- Grafana for visualization

## License

MIT
