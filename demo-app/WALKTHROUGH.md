# Demo Application - Complete Walkthrough Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Option 1: Run Locally (Without Docker)](#option-1-run-locally-without-docker)
4. [Option 2: Run with Docker](#option-2-run-with-docker)
5. [Option 3: Deploy to Kubernetes](#option-3-deploy-to-kubernetes)
6. [Testing the Application](#testing-the-application)
7. [Understanding the Code](#understanding-the-code)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This demo application is a production-ready Go web service that demonstrates:
- RESTful API design
- Health check endpoints (Kubernetes-ready)
- Prometheus metrics
- Structured logging
- Graceful shutdown
- Security best practices

**Tech Stack:**
- Language: Go 1.21
- Web Framework: Gorilla Mux
- Logging: Uber Zap
- Metrics: Prometheus client
- Container: Docker multi-stage build
- Orchestration: Kubernetes

---

## Prerequisites

### For Local Development (Option 1)
- Go 1.21 or higher
- Terminal/Command line

### For Docker (Option 2)
- Docker Desktop or Colima
- Terminal/Command line

### For Kubernetes (Option 3)
- Minikube running
- kubectl configured
- Docker for building images

**Check your setup:**
```bash
# Check Go version
go version
# Should show: go version go1.21.x or higher

# Check Docker
docker --version
# Should show: Docker version 20.x or higher

# Check Kubernetes
kubectl version --client
minikube status
```

---

## Option 1: Run Locally (Without Docker)

This is the fastest way to test the application during development.

### Step 1: Navigate to the Application Directory

```bash
cd /Users/niravsoni/repos/CKA/demo-app
```

### Step 2: Download Dependencies

```bash
# Download all Go dependencies
go mod download

# Verify dependencies
go mod verify
```

**Expected output:**
```
all modules verified
```

### Step 3: Run the Application

```bash
# Run directly with go run
go run cmd/server/main.go
```

**Expected output:**
```json
{"level":"info","ts":1234567890.123,"caller":"server/main.go:28","msg":"Configuration loaded","app_name":"demo-app","version":"1.0.0","environment":"development","port":8080}
{"level":"info","ts":1234567890.124,"caller":"server/main.go:62","msg":"Starting HTTP server","address":":8080"}
```

**The application is now running on http://localhost:8080**

### Step 4: Test the Application (Keep it running, open a new terminal)

```bash
# Test home endpoint
curl http://localhost:8080/

# Expected response:
{
  "message": "Welcome to Demo Application",
  "application": "demo-app",
  "version": "1.0.0",
  "environment": "development",
  "timestamp": "2024-01-01T00:00:00Z"
}

# Test health endpoint
curl http://localhost:8080/health

# Expected response:
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "uptime": "5m30s"
}

# Test info endpoint
curl http://localhost:8080/api/info

# Expected response:
{
  "application": "demo-app",
  "version": "1.0.0",
  "environment": "development",
  "go_version": "go1.21.x",
  "platform": "darwin/arm64",
  "timestamp": "2024-01-01T00:00:00Z",
  "endpoints": {
    "health": "/health",
    "ready": "/health/ready",
    "live": "/health/live",
    "metrics": "/metrics",
    "info": "/api/info",
    "echo": "/api/echo",
    "version": "/api/version"
  }
}

# Test echo endpoint
curl -X POST http://localhost:8080/api/echo \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello from local testing!"}'

# Expected response:
{
  "echo": "Hello from local testing!",
  "timestamp": "2024-01-01T00:00:00Z",
  "request_id": "abc-123-def-456"
}

# Test Prometheus metrics
curl http://localhost:8080/metrics

# Expected response (partial):
# HELP go_goroutines Number of goroutines that currently exist.
# TYPE go_goroutines gauge
go_goroutines 8
# HELP go_info Information about the Go environment.
# TYPE go_info gauge
go_info{version="go1.21.x"} 1
...
```

### Step 5: Stop the Application

Press `Ctrl+C` in the terminal where the app is running.

**Expected output:**
```json
{"level":"info","ts":1234567890.125,"caller":"server/main.go:75","msg":"Shutting down server..."}
{"level":"info","ts":1234567890.126,"caller":"server/main.go":82,"msg":"Server exited gracefully"}
```

### Step 6: Build a Binary (Optional)

```bash
# Build the application
go build -o bin/demo-app cmd/server/main.go

# Run the binary
./bin/demo-app

# The app will start on port 8080
```

---

## Option 2: Run with Docker

This tests the containerized version of the application.

### Step 1: Build the Docker Image

```bash
cd /Users/niravsoni/repos/CKA/demo-app

# Build with version tags
docker build -t demo-app:1.0.0 \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local") \
  .

# Tag as latest
docker tag demo-app:1.0.0 demo-app:latest
```

**Expected output:**
```
[+] Building 45.2s (15/15) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 1.23kB
 => [internal] load .dockerignore
 => => transferring context: 234B
 => [internal] load metadata for docker.io/library/golang:1.21-alpine
 => [builder 1/7] FROM docker.io/library/golang:1.21-alpine
 => [builder 2/7] RUN apk add --no-cache git ca-certificates tzdata
 => [builder 3/7] WORKDIR /build
 => [builder 4/7] COPY go.mod go.sum ./
 => [builder 5/7] RUN go mod download && go mod verify
 => [builder 6/7] COPY . .
 => [builder 7/7] RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build...
 => [stage-1 1/3] COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
 => [stage-1 2/3] COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
 => [stage-1 3/3] COPY --from=builder /build/app /app
 => exporting to image
 => => exporting layers
 => => writing image sha256:abc123...
 => => naming to docker.io/library/demo-app:1.0.0
 => => naming to docker.io/library/demo-app:latest
```

### Step 2: Verify the Image

```bash
# List images
docker images | grep demo-app

# Expected output:
demo-app    1.0.0    abc123def456    2 minutes ago    15.2MB
demo-app    latest   abc123def456    2 minutes ago    15.2MB

# Inspect the image
docker inspect demo-app:latest | grep -A 5 "ExposedPorts"
```

### Step 3: Run the Container

```bash
# Run in foreground (you'll see logs)
docker run --rm -p 8080:8080 demo-app:latest

# Or run in background (detached)
docker run -d --name demo-app -p 8080:8080 demo-app:latest
```

**Expected output (foreground):**
```json
{"level":"info","ts":1234567890.123,"caller":"server/main.go:28","msg":"Configuration loaded","app_name":"demo-app","version":"1.0.0","environment":"production","port":8080}
{"level":"info","ts":1234567890.124,"caller":"server/main.go:62","msg":"Starting HTTP server","address":":8080"}
```

### Step 4: Test the Containerized Application

```bash
# Test home endpoint
curl http://localhost:8080/

# Test health
curl http://localhost:8080/health

# Test all endpoints (same as Option 1)
```

### Step 5: View Container Logs

```bash
# If running in background
docker logs demo-app

# Follow logs in real-time
docker logs -f demo-app

# View last 20 lines
docker logs --tail 20 demo-app
```

### Step 6: Stop and Remove Container

```bash
# If running in foreground: Press Ctrl+C

# If running in background:
docker stop demo-app
docker rm demo-app

# Or force remove:
docker rm -f demo-app
```

### Step 7: Inspect Container (Optional)

```bash
# Run container with shell access (for debugging)
docker run -it --rm --entrypoint /bin/sh demo-app:latest

# Note: This won't work because we use 'scratch' base image
# The container has no shell for security reasons
```

---

## Option 3: Deploy to Kubernetes

This deploys the application to your local Minikube cluster.

### Step 1: Ensure Minikube is Running

```bash
# Check Minikube status
minikube status

# If not running, start it
minikube start

# Verify kubectl is configured
kubectl cluster-info
```

### Step 2: Build and Load Image into Minikube

```bash
cd /Users/niravsoni/repos/CKA/demo-app

# Build the image (if not already built)
docker build -t demo-app:1.0.0 .

# Load image into Minikube
minikube image load demo-app:1.0.0

# Verify image is in Minikube
minikube image ls | grep demo-app
```

**Expected output:**
```
docker.io/library/demo-app:1.0.0
```

### Step 3: Deploy to Kubernetes

```bash
# Apply all Kubernetes manifests
kubectl apply -f deployments/kubernetes/

# Or apply in order:
kubectl apply -f deployments/kubernetes/00-namespace.yaml
kubectl apply -f deployments/kubernetes/01-configmap.yaml
kubectl apply -f deployments/kubernetes/04-serviceaccount.yaml
kubectl apply -f deployments/kubernetes/02-deployment.yaml
kubectl apply -f deployments/kubernetes/03-service.yaml
kubectl apply -f deployments/kubernetes/05-ingress.yaml
kubectl apply -f deployments/kubernetes/06-networkpolicy.yaml
kubectl apply -f deployments/kubernetes/07-servicemonitor.yaml
kubectl apply -f deployments/kubernetes/08-hpa.yaml
kubectl apply -f deployments/kubernetes/09-pdb.yaml
```

**Expected output:**
```
namespace/demo-app created
configmap/demo-app-config created
serviceaccount/demo-app created
role.rbac.authorization.k8s.io/demo-app created
rolebinding.rbac.authorization.k8s.io/demo-app created
deployment.apps/demo-app created
service/demo-app created
ingress.networking.k8s.io/demo-app created
networkpolicy.networking.k8s.io/demo-app created
servicemonitor.monitoring.coreos.com/demo-app created
horizontalpodautoscaler.autoscaling/demo-app created
poddisruptionbudget.policy/demo-app created
```

### Step 4: Verify Deployment

```bash
# Check all resources in demo-app namespace
kubectl get all -n demo-app

# Expected output:
NAME                            READY   STATUS    RESTARTS   AGE
pod/demo-app-xxxxxxxxx-xxxxx    1/1     Running   0          30s
pod/demo-app-xxxxxxxxx-yyyyy    1/1     Running   0          30s

NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/demo-app   ClusterIP   10.96.123.456   <none>        80/TCP    30s

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/demo-app   2/2     2            2           30s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/demo-app-xxxxxxxxx    2         2         2       30s

# Check pod details
kubectl describe pod -n demo-app -l app=demo-app

# Check pod logs
kubectl logs -n demo-app -l app=demo-app --tail=20
```

### Step 5: Access the Application

#### Method A: Via Ingress (Recommended)

```bash
# Start minikube tunnel (in a separate terminal)
minikube tunnel

# Add to /etc/hosts
echo "127.0.0.1 demo-app.local" | sudo tee -a /etc/hosts

# Test the application
curl http://demo-app.local/
curl http://demo-app.local/health
curl http://demo-app.local/api/info
```

#### Method B: Via Port Forward

```bash
# Port forward to the service
kubectl port-forward -n demo-app svc/demo-app 8080:80

# In another terminal, test:
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/api/info
```

#### Method C: Via NodePort (Testing)

```bash
# Change service type to NodePort
kubectl patch svc demo-app -n demo-app -p '{"spec":{"type":"NodePort"}}'

# Get the service URL
minikube service demo-app -n demo-app --url

# Use the returned URL to test
curl $(minikube service demo-app -n demo-app --url)/
```

### Step 6: Monitor the Application

```bash
# Watch pods
kubectl get pods -n demo-app -w

# Check HPA status
kubectl get hpa -n demo-app

# Check resource usage
kubectl top pods -n demo-app

# Check ServiceMonitor
kubectl get servicemonitor -n demo-app

# View events
kubectl get events -n demo-app --sort-by='.lastTimestamp'
```

### Step 7: Scale the Application

```bash
# Manual scaling
kubectl scale deployment demo-app -n demo-app --replicas=3

# Verify
kubectl get pods -n demo-app

# Scale back
kubectl scale deployment demo-app -n demo-app --replicas=2
```

### Step 8: Cleanup

```bash
# Delete all resources
kubectl delete namespace demo-app

# Or delete individually
kubectl delete -f deployments/kubernetes/
```

---

## Testing the Application

### Complete Test Suite

Create a test script:

```bash
# Create test script
cat > test-demo-app.sh << 'EOF'
#!/bin/bash

BASE_URL="${1:-http://localhost:8080}"

echo "Testing Demo Application at $BASE_URL"
echo "========================================"

# Test 1: Home endpoint
echo -e "\n1. Testing Home Endpoint (GET /)"
curl -s $BASE_URL/ | jq .

# Test 2: Health endpoint
echo -e "\n2. Testing Health Endpoint (GET /health)"
curl -s $BASE_URL/health | jq .

# Test 3: Liveness probe
echo -e "\n3. Testing Liveness Probe (GET /health/live)"
curl -s $BASE_URL/health/live | jq .

# Test 4: Readiness probe
echo -e "\n4. Testing Readiness Probe (GET /health/ready)"
curl -s $BASE_URL/health/ready | jq .

# Test 5: Info endpoint
echo -e "\n5. Testing Info Endpoint (GET /api/info)"
curl -s $BASE_URL/api/info | jq .

# Test 6: Version endpoint
echo -e "\n6. Testing Version Endpoint (GET /api/version)"
curl -s $BASE_URL/api/version | jq .

# Test 7: Echo endpoint
echo -e "\n7. Testing Echo Endpoint (POST /api/echo)"
curl -s -X POST $BASE_URL/api/echo \
  -H "Content-Type: application/json" \
  -d '{"message":"Test message from script"}' | jq .

# Test 8: Metrics endpoint
echo -e "\n8. Testing Metrics Endpoint (GET /metrics)"
curl -s $BASE_URL/metrics | head -20

echo -e "\n========================================"
echo "All tests completed!"
EOF

chmod +x test-demo-app.sh

# Run tests
./test-demo-app.sh

# Or test Kubernetes deployment
./test-demo-app.sh http://demo-app.local
```

### Load Testing (Optional)

```bash
# Install hey (HTTP load generator)
# macOS: brew install hey
# Or download from: https://github.com/rakyll/hey

# Run load test
hey -n 1000 -c 10 http://localhost:8080/

# Expected output:
Summary:
  Total:        2.5432 secs
  Slowest:      0.0234 secs
  Fastest:      0.0012 secs
  Average:      0.0045 secs
  Requests/sec: 393.21
```

---

## Understanding the Code

### Application Structure

```
demo-app/
├── cmd/server/main.go              # Entry point
│   ├── Initializes logger
│   ├── Loads configuration
│   ├── Sets up routes
│   ├── Starts HTTP server
│   └── Handles graceful shutdown
│
├── internal/
│   ├── config/config.go            # Configuration
│   │   └── Reads environment variables
│   │
│   ├── handlers/handlers.go        # HTTP handlers
│   │   ├── Home()      - GET /
│   │   ├── Info()      - GET /api/info
│   │   ├── Echo()      - POST /api/echo
│   │   └── Version()   - GET /api/version
│   │
│   └── middleware/middleware.go    # Middleware
│       ├── RequestID    - Adds unique ID to each request
│       ├── RequestLogger - Logs all HTTP requests
│       ├── Recovery     - Catches panics
│       └── CORS         - Handles CORS headers
│
└── pkg/health/health.go            # Health checks
    ├── Health()  - GET /health
    ├── Ready()   - GET /health/ready
    └── Live()    - GET /health/live
```

### Key Features Explained

#### 1. Graceful Shutdown
```go
// Listens for SIGINT/SIGTERM
quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit

// Gives 30 seconds for in-flight requests to complete
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
srv.Shutdown(ctx)
```

#### 2. Request ID Tracking
Every request gets a unique ID for tracing:
```bash
curl -v http://localhost:8080/
# Response header: X-Request-ID: abc-123-def-456
```

#### 3. Structured Logging
All logs are in JSON format:
```json
{
  "level": "info",
  "ts": 1234567890.123,
  "caller": "handlers/handlers.go:45",
  "msg": "Echo request processed",
  "message": "Hello",
  "request_id": "abc-123"
}
```

#### 4. Health Checks
- **Liveness**: Is the app alive? (for Kubernetes to restart if dead)
- **Readiness**: Is the app ready to serve traffic? (for load balancer)
- **Health**: Overall health status

---

## Troubleshooting

### Issue 1: Port Already in Use

**Error:**
```
listen tcp :8080: bind: address already in use
```

**Solution:**
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=8081 go run cmd/server/main.go
```

### Issue 2: Go Dependencies Not Found

**Error:**
```
package github.com/gorilla/mux is not in GOROOT
```

**Solution:**
```bash
cd demo-app
go mod download
go mod tidy
```

### Issue 3: Docker Build Fails

**Error:**
```
failed to solve with frontend dockerfile.v0
```

**Solution:**
```bash
# Clean Docker cache
docker system prune -a

# Rebuild
docker build -t demo-app:latest .
```

### Issue 4: Kubernetes Pods Not Starting

**Error:**
```
ImagePullBackOff or ErrImagePull
```

**Solution:**
```bash
# Ensure image is in Minikube
minikube image load demo-app:1.0.0

# Or change imagePullPolicy
kubectl patch deployment demo-app -n demo-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"demo-app","imagePullPolicy":"Never"}]}}}}'
```

### Issue 5: Cannot Access via Ingress

**Error:**
```
curl: (7) Failed to connect to demo-app.local port 80
```

**Solution:**
```bash
# Ensure minikube tunnel is running
minikube tunnel

# Check /etc/hosts
cat /etc/hosts | grep demo-app.local

# If missing, add it:
echo "127.0.0.1 demo-app.local" | sudo tee -a /etc/hosts

# Check ingress
kubectl get ingress -n demo-app
```

---

## Next Steps

1. **Modify the Code**: Try adding a new endpoint
2. **Add Tests**: Create unit tests for handlers
3. **CI/CD**: Set up Jenkins pipeline
4. **Monitoring**: View metrics in Grafana
5. **Production**: Deploy to a real Kubernetes cluster

---

## Quick Reference

### Common Commands

```bash
# Local development
go run cmd/server/main.go
go build -o bin/demo-app cmd/server/main.go

# Docker
docker build -t demo-app:latest .
docker run -p 8080:8080 demo-app:latest
docker logs demo-app

# Kubernetes
kubectl apply -f deployments/kubernetes/
kubectl get all -n demo-app
kubectl logs -n demo-app -l app=demo-app
kubectl port-forward -n demo-app svc/demo-app 8080:80
kubectl delete namespace demo-app

# Testing
curl http://localhost:8080/health
curl http://localhost:8080/api/info
curl -X POST http://localhost:8080/api/echo -H "Content-Type: application/json" -d '{"message":"test"}'
```

### Environment Variables

```bash
# Configuration
export APP_NAME="my-app"
export APP_VERSION="2.0.0"
export ENVIRONMENT="production"
export PORT=8080
export LOG_LEVEL="debug"

# Run with custom config
go run cmd/server/main.go
```

---

## Support

- Application README: `demo-app/README.md`
- Deployment Guide: `demo-app/DEPLOYMENT.md`
- Kubernetes Manifests: `demo-app/deployments/kubernetes/`
- Main Documentation: `docs/` directory

Happy coding! 🚀
