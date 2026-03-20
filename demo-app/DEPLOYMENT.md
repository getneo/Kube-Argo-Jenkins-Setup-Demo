# Demo Application - Deployment Guide

## Overview

This document provides a complete guide for deploying the demo application to Kubernetes with best practices.

## Application Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Demo Application                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Ingress    │  │  Service     │  │  Deployment  │    │
│  │ (demo-app    │→ │  (ClusterIP) │→ │  (2 replicas)│    │
│  │  .local)     │  │              │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                              ↓             │
│                                     ┌──────────────┐       │
│                                     │  Pod (Go App)│       │
│                                     │  - Port 8080 │       │
│                                     │  - Health    │       │
│                                     │  - Metrics   │       │
│                                     └──────────────┘       │
│                                                             │
│  Supporting Resources:                                      │
│  - ConfigMap (environment variables)                        │
│  - ServiceAccount + RBAC                                    │
│  - NetworkPolicy (security)                                 │
│  - ServiceMonitor (Prometheus)                              │
│  - HPA (autoscaling)                                        │
│  - PodDisruptionBudget (HA)                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Files Created

### Application Code
```
demo-app/
├── cmd/server/main.go              # Application entry point (103 lines)
├── internal/
│   ├── config/config.go            # Configuration management (42 lines)
│   ├── handlers/handlers.go        # HTTP handlers (159 lines)
│   └── middleware/middleware.go    # HTTP middleware (111 lines)
├── pkg/health/health.go            # Health checks (97 lines)
├── go.mod                          # Go dependencies
├── Dockerfile                      # Multi-stage build (60 lines)
├── .dockerignore                   # Docker build exclusions
└── README.md                       # Application documentation
```

### Kubernetes Manifests
```
demo-app/deployments/kubernetes/
├── 00-namespace.yaml               # Namespace definition
├── 01-configmap.yaml               # Configuration
├── 02-deployment.yaml              # Deployment with security (159 lines)
├── 03-service.yaml                 # Service definition
├── 04-serviceaccount.yaml          # RBAC configuration
├── 05-ingress.yaml                 # Ingress rules
├── 06-networkpolicy.yaml           # Network security
├── 07-servicemonitor.yaml          # Prometheus integration
├── 08-hpa.yaml                     # Horizontal Pod Autoscaler
└── 09-pdb.yaml                     # Pod Disruption Budget
```

## Security Features Implemented

### 1. Container Security
- ✅ Non-root user (UID 65534)
- ✅ Read-only root filesystem
- ✅ No privilege escalation
- ✅ Dropped all capabilities
- ✅ Seccomp profile (RuntimeDefault)
- ✅ Minimal base image (scratch)
- ✅ Static binary (no dependencies)

### 2. Pod Security
- ✅ Security context at pod level
- ✅ Non-root enforcement
- ✅ FSGroup for volume permissions
- ✅ Service account with minimal RBAC

### 3. Network Security
- ✅ NetworkPolicy with ingress/egress rules
- ✅ Only allow traffic from ingress controller
- ✅ Only allow metrics scraping from Prometheus
- ✅ DNS resolution allowed
- ✅ HTTPS egress allowed

### 4. Resource Management
- ✅ CPU requests: 100m
- ✅ CPU limits: 500m
- ✅ Memory requests: 128Mi
- ✅ Memory limits: 256Mi
- ✅ Horizontal Pod Autoscaler configured
- ✅ Pod Disruption Budget for HA

## Deployment Steps

### Prerequisites
1. Minikube running
2. kubectl configured
3. Ingress controller installed
4. Prometheus operator installed (for ServiceMonitor)

### Step 1: Build the Docker Image

```bash
cd demo-app

# Build the image
docker build -t demo-app:1.0.0 \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg GIT_COMMIT=$(git rev-parse --short HEAD) \
  .

# Tag for Minikube
docker tag demo-app:1.0.0 demo-app:latest

# Load into Minikube (if using Minikube)
minikube image load demo-app:latest
```

### Step 2: Deploy to Kubernetes

```bash
# Apply all manifests in order
kubectl apply -f deployments/kubernetes/

# Or apply individually
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

### Step 3: Verify Deployment

```bash
# Check namespace
kubectl get namespace demo-app

# Check all resources
kubectl get all -n demo-app

# Check pods
kubectl get pods -n demo-app

# Check deployment
kubectl describe deployment demo-app -n demo-app

# Check service
kubectl get svc -n demo-app

# Check ingress
kubectl get ingress -n demo-app
```

### Step 4: Access the Application

#### Option 1: Via Ingress (Recommended)

```bash
# Ensure minikube tunnel is running
minikube tunnel

# Add to /etc/hosts
echo "127.0.0.1 demo-app.local" | sudo tee -a /etc/hosts

# Access the application
curl http://demo-app.local/
curl http://demo-app.local/api/info
curl http://demo-app.local/health
```

#### Option 2: Via Port Forward

```bash
# Port forward to service
kubectl port-forward -n demo-app svc/demo-app 8080:80

# Access the application
curl http://localhost:8080/
curl http://localhost:8080/api/info
curl http://localhost:8080/health
```

#### Option 3: Via NodePort (for testing)

```bash
# Change service type to NodePort
kubectl patch svc demo-app -n demo-app -p '{"spec":{"type":"NodePort"}}'

# Get the NodePort
kubectl get svc demo-app -n demo-app

# Access via Minikube IP
minikube service demo-app -n demo-app --url
```

## Testing the Application

### Health Checks

```bash
# Liveness probe
curl http://demo-app.local/health/live

# Readiness probe
curl http://demo-app.local/health/ready

# General health
curl http://demo-app.local/health
```

### API Endpoints

```bash
# Home endpoint
curl http://demo-app.local/

# Application info
curl http://demo-app.local/api/info

# Version
curl http://demo-app.local/api/version

# Echo endpoint
curl -X POST http://demo-app.local/api/echo \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello from demo-app!"}'
```

### Metrics

```bash
# Prometheus metrics
curl http://demo-app.local/metrics
```

## Monitoring

### Prometheus Integration

The ServiceMonitor automatically configures Prometheus to scrape metrics:

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n demo-app

# Verify in Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open: http://localhost:9090
# Query: up{job="demo-app"}
```

### Grafana Dashboards

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Login: admin / admin123
# Import dashboard for demo-app metrics
```

## Scaling

### Manual Scaling

```bash
# Scale to 3 replicas
kubectl scale deployment demo-app -n demo-app --replicas=3

# Verify
kubectl get pods -n demo-app
```

### Autoscaling

The HPA is configured to scale based on CPU and memory:

```bash
# Check HPA status
kubectl get hpa -n demo-app

# Describe HPA
kubectl describe hpa demo-app -n demo-app

# Generate load to test autoscaling
kubectl run -it --rm load-generator --image=busybox /bin/sh
# Inside the pod:
while true; do wget -q -O- http://demo-app.demo-app.svc.cluster.local; done
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n demo-app

# Describe pod
kubectl describe pod <pod-name> -n demo-app

# Check logs
kubectl logs <pod-name> -n demo-app

# Check events
kubectl get events -n demo-app --sort-by='.lastTimestamp'
```

### Image Pull Issues

```bash
# If using Minikube, ensure image is loaded
minikube image ls | grep demo-app

# Load image if missing
minikube image load demo-app:latest

# Or use imagePullPolicy: Never in deployment
```

### Network Issues

```bash
# Check NetworkPolicy
kubectl get networkpolicy -n demo-app

# Describe NetworkPolicy
kubectl describe networkpolicy demo-app -n demo-app

# Test connectivity from another pod
kubectl run -it --rm debug --image=busybox -n demo-app /bin/sh
# Inside the pod:
wget -O- http://demo-app.demo-app.svc.cluster.local
```

### Resource Issues

```bash
# Check resource usage
kubectl top pods -n demo-app

# Check node resources
kubectl top nodes

# Describe node
kubectl describe node minikube | grep -A 5 "Allocated resources"
```

## Cleanup

```bash
# Delete all resources
kubectl delete namespace demo-app

# Or delete individually
kubectl delete -f deployments/kubernetes/
```

## Best Practices Implemented

### 1. **High Availability**
- Multiple replicas (2 minimum)
- Pod anti-affinity rules
- Pod Disruption Budget
- Rolling update strategy

### 2. **Observability**
- Structured logging (Zap)
- Prometheus metrics
- Health check endpoints
- Request ID tracking

### 3. **Security**
- Non-root containers
- Read-only filesystem
- Network policies
- RBAC with minimal permissions
- Security contexts

### 4. **Resource Management**
- Resource requests and limits
- Horizontal Pod Autoscaler
- Graceful shutdown
- Startup/Liveness/Readiness probes

### 5. **Configuration Management**
- ConfigMap for environment variables
- Secrets for sensitive data (if needed)
- Environment-specific configs

## Next Steps

1. **CI/CD Integration**
   - Create Jenkins pipeline
   - Set up ArgoCD application
   - Implement GitOps workflow

2. **Enhanced Monitoring**
   - Create custom Grafana dashboards
   - Set up alerting rules
   - Add distributed tracing

3. **Production Readiness**
   - Add TLS/HTTPS
   - Implement rate limiting
   - Add authentication/authorization
   - Set up backup and disaster recovery

## Resources

- Application README: `demo-app/README.md`
- Kubernetes manifests: `demo-app/deployments/kubernetes/`
- Dockerfile: `demo-app/Dockerfile`
- Source code: `demo-app/cmd/` and `demo-app/internal/`

## Support

For issues or questions:
1. Check application logs: `kubectl logs -n demo-app <pod-name>`
2. Check events: `kubectl get events -n demo-app`
3. Review documentation in `docs/` directory
