# Deployment Workflow Guide

Complete guide for managing deployments across all environments in your Kubernetes CI/CD pipeline.

## Table of Contents

1. [Overview](#overview)
2. [Making Changes](#making-changes)
3. [Environment Promotion Strategy](#environment-promotion-strategy)
4. [What ArgoCD Manages](#what-argocd-manages)
5. [Testing the Complete Flow](#testing-the-complete-flow)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### Architecture

```
Developer → Git Push → Jenkins (CI) → Docker Image → Git (Update Manifests) → ArgoCD (CD) → Kubernetes
```

### Environments

| Environment | Namespace | Purpose | Auto-Deploy | Image Tag |
|-------------|-----------|---------|-------------|-----------|
| **Development** | `demo-app-dev` | Active development, frequent changes | ✅ Yes | `latest` |
| **Staging** | `demo-app-staging` | Pre-production testing, QA | ✅ Yes | `latest` |
| **Production** | `demo-app-prod` | Live environment | ❌ Manual | Semantic version (e.g., `1.0.0`) |

---

## Making Changes

### Type 1: Application Code Changes

**When**: Modifying Go code, adding features, fixing bugs

**Process**:

1. **Make code changes** in `demo-app/main.go`
   ```bash
   cd demo-app
   # Edit main.go
   vim main.go
   ```

2. **Test locally** (optional)
   ```bash
   go run main.go
   # Test at http://localhost:8080
   ```

3. **Build and push Docker image**
   ```bash
   # Option A: Use local CI script (for local testing)
   ./scripts/local-ci-build.sh

   # Option B: Commit and push (triggers Jenkins)
   git add demo-app/main.go
   git commit -m "feat: add new feature"
   git push origin main
   ```

4. **What happens next**:
   - Jenkins builds Docker image
   - Image tagged as `latest` and pushed to registry
   - Jenkins updates Helm values with new image tag
   - ArgoCD detects changes and deploys to dev/staging
   - Production requires manual promotion (see below)

**Files Modified**:
- `demo-app/main.go` - Your application code
- `demo-app/Dockerfile` - Only if changing build process

---

### Type 2: Kubernetes Configuration Changes

**When**: Changing replicas, resources, environment variables, etc.

**Process**:

1. **Identify the correct file**:
   ```
   demo-app/helm-chart/demo-app/
   ├── values-dev.yaml      # Dev-specific config
   ├── values.yaml          # Staging config (default)
   └── values-prod.yaml     # Production config
   ```

2. **Make changes** (example: increase replicas)
   ```bash
   # Edit staging replicas
   vim demo-app/helm-chart/demo-app/values.yaml

   # Change:
   replicaCount: 2  # from 1 to 2
   ```

3. **Commit and push**
   ```bash
   git add demo-app/helm-chart/demo-app/values.yaml
   git commit -m "config: increase staging replicas to 2"
   git push origin main
   ```

4. **What happens next**:
   - ArgoCD detects Helm values change
   - Auto-syncs dev and staging (within 3 minutes)
   - Production requires manual sync

**Files to Modify**:
- `values-dev.yaml` - Dev environment config
- `values.yaml` - Staging environment config  
- `values-prod.yaml` - Production environment config
- `templates/*.yaml` - Only for structural changes

---

### Type 3: Infrastructure Changes

**When**: Adding new Kubernetes resources, changing namespaces, RBAC, etc.

**Process**:

1. **Modify infrastructure files**:
   ```
   k8s/setup/
   ├── namespaces-separated.yaml  # Namespace definitions
   ├── resource-quota.yaml        # Resource limits
   └── rbac.yaml                  # Access control
   ```

2. **Apply manually** (ArgoCD doesn't manage these)
   ```bash
   kubectl apply -f k8s/setup/namespaces-separated.yaml
   ```

3. **Commit for documentation**
   ```bash
   git add k8s/setup/
   git commit -m "infra: update resource quotas"
   git push origin main
   ```

**⚠️ Important**: Infrastructure changes are NOT managed by ArgoCD. Apply manually.

---

## Environment Promotion Strategy

### Development → Staging (Automatic)

**Trigger**: Push to `main` branch

```bash
# Make changes
git add .
git commit -m "feat: new feature"
git push origin main

# Jenkins builds image with 'latest' tag
# ArgoCD auto-deploys to dev and staging
```

**Timeline**:
- Jenkins build: 2-5 minutes
- ArgoCD sync: 1-3 minutes
- **Total**: ~5-8 minutes

---

### Staging → Production (Manual)

**Why Manual?**: Production requires:
- ✅ QA approval
- ✅ Semantic versioning
- ✅ Explicit promotion decision
- ✅ Rollback capability

**Process**:

#### Step 1: Tag a Release

```bash
# After testing in staging, create a release tag
git tag -a v1.0.1 -m "Release v1.0.1: Bug fixes and improvements"
git push origin v1.0.1
```

#### Step 2: Build Production Image

```bash
# Jenkins job or manual build
docker build -t demo-app:1.0.1 demo-app/
docker tag demo-app:1.0.1 demo-app:latest

# For Minikube (local)
eval $(minikube docker-env)
docker build -t demo-app:1.0.1 demo-app/
```

#### Step 3: Update Production Values

```bash
# Edit production Helm values
vim demo-app/helm-chart/demo-app/values-prod.yaml

# Update image tag:
image:
  tag: "1.0.1"  # Change from previous version

# Commit
git add demo-app/helm-chart/demo-app/values-prod.yaml
git commit -m "release: promote v1.0.1 to production"
git push origin main
```

#### Step 4: Sync Production (Manual)

```bash
# Option A: Via ArgoCD UI
# 1. Open ArgoCD UI: http://localhost:8080
# 2. Click on 'demo-app-prod'
# 3. Click 'SYNC' button
# 4. Review changes
# 5. Click 'SYNCHRONIZE'

# Option B: Via kubectl
kubectl patch application demo-app-prod -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# Option C: Via argocd CLI
argocd app sync demo-app-prod
```

#### Step 5: Verify Production

```bash
# Check deployment
kubectl get pods -n demo-app-prod

# Check image version
kubectl get deployment demo-app-prod -n demo-app-prod \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Test application
kubectl port-forward -n demo-app-prod svc/demo-app-prod 8084:80
curl http://localhost:8084/health
```

---

## What ArgoCD Manages

### ✅ Managed by ArgoCD (GitOps)

**DO**: Commit to Git, let ArgoCD deploy

| Resource | Location | Auto-Sync |
|----------|----------|-----------|
| **Deployments** | `helm-chart/templates/deployment.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |
| **Services** | `helm-chart/templates/service.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |
| **ConfigMaps** | `helm-chart/templates/configmap.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |
| **Secrets** | `helm-chart/templates/secrets.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |
| **HPA** | `helm-chart/templates/hpa.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |
| **Ingress** | `helm-chart/templates/ingress.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |
| **ServiceAccount** | `helm-chart/templates/serviceaccount.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |
| **RBAC** | `helm-chart/templates/role*.yaml` | Dev: ✅ Staging: ✅ Prod: ❌ |

**How to Change**:
```bash
# 1. Edit Helm values or templates
vim demo-app/helm-chart/demo-app/values-dev.yaml

# 2. Commit and push
git add .
git commit -m "config: update configuration"
git push origin main

# 3. ArgoCD auto-deploys (dev/staging) or manual sync (prod)
```

---

### ❌ NOT Managed by ArgoCD (Manual)

**DO**: Apply with `kubectl`, then commit for documentation

| Resource | Location | Why Manual |
|----------|----------|------------|
| **Namespaces** | `k8s/setup/namespaces-separated.yaml` | Created before ArgoCD apps |
| **Resource Quotas** | `k8s/setup/namespaces-separated.yaml` | Cluster-level policy |
| **Network Policies** | `k8s/setup/namespaces-separated.yaml` | Security policy |
| **ArgoCD Applications** | `argocd/applications/demo-app-dev.yaml` | ArgoCD can't manage itself |
| **Cluster Roles** | `k8s/setup/rbac.yaml` | Cluster-wide permissions |
| **Storage Classes** | `k8s/setup/storage.yaml` | Infrastructure |
| **Monitoring Stack** | `k8s/monitoring/` | Separate lifecycle |

**How to Change**:
```bash
# 1. Edit file
vim k8s/setup/namespaces-separated.yaml

# 2. Apply manually
kubectl apply -f k8s/setup/namespaces-separated.yaml

# 3. Commit for documentation
git add k8s/setup/namespaces-separated.yaml
git commit -m "infra: update resource quotas"
git push origin main
```

---

## Testing the Complete Flow

### Scenario: Add a New Feature

Let's walk through a complete example: Adding a `/version` endpoint

#### Step 1: Make Code Changes

```bash
cd demo-app

# Edit main.go
cat >> main.go << 'EOF'

// Version endpoint
func versionHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "version": "1.1.0",
        "build": "2024-03-24",
    })
}
EOF

# Update routes (add to main function)
# http.HandleFunc("/version", versionHandler)
```

#### Step 2: Test Locally

```bash
# Build and test
go run main.go

# In another terminal
curl http://localhost:8080/version
# Expected: {"version":"1.1.0","build":"2024-03-24"}
```

#### Step 3: Build Docker Image

```bash
# For local Minikube
eval $(minikube docker-env)
docker build -t demo-app:latest demo-app/

# Verify image
docker images | grep demo-app
```

#### Step 4: Commit Changes

```bash
git add demo-app/main.go
git commit -m "feat: add version endpoint"
git push origin main
```

#### Step 5: Verify Dev Deployment

```bash
# Wait for ArgoCD to sync (1-3 minutes)
kubectl get pods -n demo-app-dev -w

# Once running, test
kubectl port-forward -n demo-app-dev svc/demo-app-dev 8082:80
curl http://localhost:8082/version
```

#### Step 6: Verify Staging Deployment

```bash
# Check staging
kubectl get pods -n demo-app-staging

# Test
kubectl port-forward -n demo-app-staging svc/demo-app-staging 8083:80
curl http://localhost:8083/version
```

#### Step 7: Promote to Production

```bash
# 1. Create release tag
git tag -a v1.1.0 -m "Release v1.1.0: Add version endpoint"
git push origin v1.1.0

# 2. Build production image
docker build -t demo-app:1.1.0 demo-app/

# 3. Update production values
vim demo-app/helm-chart/demo-app/values-prod.yaml
# Change: tag: "1.1.0"

git add demo-app/helm-chart/demo-app/values-prod.yaml
git commit -m "release: promote v1.1.0 to production"
git push origin main

# 4. Manual sync in ArgoCD UI or:
kubectl patch application demo-app-prod -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# 5. Verify
kubectl get pods -n demo-app-prod
kubectl port-forward -n demo-app-prod svc/demo-app-prod 8084:80
curl http://localhost:8084/version
```

---

## Best Practices

### 1. Version Control

```bash
# ✅ Good: Semantic versioning for production
git tag -a v1.2.3 -m "Release v1.2.3"

# ❌ Bad: Using 'latest' in production
image:
  tag: "latest"  # Never in production!
```

### 2. Configuration Management

```bash
# ✅ Good: Environment-specific values
values-dev.yaml:     replicaCount: 1
values.yaml:         replicaCount: 2  (staging)
values-prod.yaml:    replicaCount: 3

# ❌ Bad: Same config for all environments
```

### 3. Secrets Management

```bash
# ✅ Good: Use Kubernetes Secrets, never commit
kubectl create secret generic db-password \
  --from-literal=password='secure-password' \  # pragma: allowlist secret
  -n demo-app-prod

# ❌ Bad: Hardcoded in values.yaml
database:
  password: "my-password"  # pragma: allowlist secret
  # Never do this!
```

### 4. Resource Limits

```yaml
# ✅ Good: Always set limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# ❌ Bad: No limits (can crash cluster)
resources: {}
```

### 5. Health Checks

```yaml
# ✅ Good: Proper health checks
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 6. Rollback Strategy

```bash
# ✅ Good: Keep previous versions
kubectl rollout history deployment/demo-app-prod -n demo-app-prod
kubectl rollout undo deployment/demo-app-prod -n demo-app-prod

# Or via ArgoCD
argocd app rollback demo-app-prod <revision>
```

### 7. Change Management

| Change Type | Dev | Staging | Production |
|-------------|-----|---------|------------|
| **Code changes** | Auto-deploy | Auto-deploy | Manual approval + tag |
| **Config changes** | Auto-deploy | Auto-deploy | Manual approval |
| **Infrastructure** | Manual | Manual | Manual + Change ticket |
| **Secrets** | Manual | Manual | Manual + Audit |

---

## Troubleshooting

### Issue: ArgoCD Shows "OutOfSync"

**Cause**: Git state doesn't match cluster state

**Solution**:
```bash
# Check what's different
kubectl get application demo-app-dev -n argocd -o yaml

# Force sync
kubectl patch application demo-app-dev -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Issue: Image Not Found

**Cause**: Image not in Minikube's Docker daemon

**Solution**:
```bash
# Use Minikube's Docker
eval $(minikube docker-env)

# Rebuild image
docker build -t demo-app:latest demo-app/

# Verify
docker images | grep demo-app
```

### Issue: Pods Stuck in Pending

**Cause**: Resource quota exceeded

**Solution**:
```bash
# Check quota
kubectl describe resourcequota -n demo-app-dev

# Increase if needed
kubectl edit resourcequota demo-app-dev-quota -n demo-app-dev
```

### Issue: ArgoCD Not Detecting Changes

**Cause**: Cache issue

**Solution**:
```bash
# Restart repo-server
kubectl delete pod -n argocd \
  -l app.kubernetes.io/name=argocd-repo-server

# Wait for restart
kubectl get pods -n argocd -w
```

---

## Quick Reference

### Common Commands

```bash
# Check all environments
kubectl get pods -A | grep demo-app

# Check ArgoCD status
kubectl get applications -n argocd

# Force sync
kubectl patch application demo-app-dev -n argocd \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# View logs
kubectl logs -f deployment/demo-app-dev -n demo-app-dev

# Port forward for testing
kubectl port-forward -n demo-app-dev svc/demo-app-dev 8082:80
kubectl port-forward -n demo-app-staging svc/demo-app-staging 8083:80
kubectl port-forward -n demo-app-prod svc/demo-app-prod 8084:80

# Check image version
kubectl get deployment demo-app-prod -n demo-app-prod \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### File Structure Reference

```
.
├── demo-app/
│   ├── main.go                    # Application code (ArgoCD: No)
│   ├── Dockerfile                 # Build config (ArgoCD: No)
│   └── helm-chart/demo-app/
│       ├── values-dev.yaml        # Dev config (ArgoCD: Yes)
│       ├── values.yaml            # Staging config (ArgoCD: Yes)
│       ├── values-prod.yaml       # Prod config (ArgoCD: Yes)
│       └── templates/             # K8s templates (ArgoCD: Yes)
│
├── k8s/setup/
│   ├── namespaces-separated.yaml  # Namespaces (ArgoCD: No - Manual)
│   ├── resource-quota.yaml        # Quotas (ArgoCD: No - Manual)
│   └── rbac.yaml                  # RBAC (ArgoCD: No - Manual)
│
├── argocd/applications/
│   └── demo-app-dev.yaml          # ArgoCD apps (ArgoCD: No - Manual)
│
└── scripts/
    └── local-ci-build.sh          # Local build script
```

---

## Summary

### Development Workflow
1. Make changes → Commit → Push
2. Jenkins builds image (or use local-ci-build.sh)
3. ArgoCD auto-deploys to dev/staging
4. Test in staging
5. Manual promotion to production

### Key Principles
- **GitOps**: All application config in Git
- **Automation**: Dev/Staging auto-deploy
- **Control**: Production requires approval
- **Separation**: Infrastructure managed separately
- **Versioning**: Semantic versions for production
- **Testing**: Always test in staging first

### Remember
- ✅ Application changes → Git → ArgoCD
- ✅ Infrastructure changes → kubectl → Git (for docs)
- ✅ Production → Always manual, always tagged
- ✅ Secrets → Never in Git, always in Kubernetes Secrets
- ✅ Test → Dev → Staging → Production

---

**Next Steps**:
- Try the complete flow with a real change
- Set up monitoring and alerts
- Implement automated testing in staging
- Create runbooks for common operations
