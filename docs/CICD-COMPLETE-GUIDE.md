# Complete CI/CD Pipeline Guide
## Jenkins + ArgoCD + GitOps - Your Working Configuration

> **Status**: ✅ Jenkins Running | ✅ ArgoCD Installed | ✅ Demo App Ready  
> **Last Updated**: 2026-03-23  
> **Purpose**: Consolidated guide combining docs/06-cicd-pipeline.md and docs/CI-CD-SETUP-GUIDE.md

---

## Table of Contents

1. [Quick Start (15 Minutes)](#quick-start-15-minutes)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites Verification](#prerequisites-verification)
4. [Jenkins CI Setup](#jenkins-ci-setup)
5. [ArgoCD CD Setup](#argocd-cd-setup)
6. [GitOps Workflow](#gitops-workflow)
7. [Testing & Validation](#testing--validation)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

---

## Quick Start (15 Minutes)

### Step 1: Verify Services (2 min)

```bash
# Check all services
kubectl get pods -n jenkins    # jenkins-0 should be Running
kubectl get pods -n argocd     # argocd pods should be Running
kubectl get pods -n monitoring # prometheus/grafana Running

# Access UIs
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &
kubectl port-forward -n argocd svc/argocd-server 8081:443 &

# Jenkins: http://localhost:8080 (admin/<your-password>)
# ArgoCD: https://localhost:8081 (admin/<get-password-below>)

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Step 2: Create Jenkins Pipeline (5 min)

```bash
# 1. Open Jenkins: http://localhost:8080
# 2. Click "New Item" → Enter "demo-app-ci" → Select "Pipeline" → OK
# 3. Configure:
#    - Build Triggers: ✓ GitHub hook trigger for GITScm polling
#    - Pipeline: Pipeline script from SCM
#    - SCM: Git
#    - Repository URL: https://github.com/YOUR_USERNAME/CKA
#    - Credentials: (create git-credentials)
#    - Branch: */main
#    - Script Path: demo-app/Jenkinsfile
# 4. Save

# Create credentials (if not exists):
# Manage Jenkins → Credentials → Add:
#   - docker-registry-credentials (Docker Hub)
#   - git-credentials (GitHub token)
```

### Step 3: Create ArgoCD Application (5 min)

```bash
# Update manifest with your GitHub username
sed -i '' 's/your-username/YOUR_GITHUB_USERNAME/g' #pragma: allowlist secret\
  argocd/applications/demo-app-dev.yaml

# Apply
kubectl apply -f argocd/applications/demo-app-dev.yaml

# Verify
kubectl get application -n argocd demo-app-dev

# Sync in ArgoCD UI
# Open https://localhost:8081 → Click demo-app-dev → Click Sync
```

### Step 4: Test Pipeline (3 min)

```bash
# Make a test change
echo "// Test $(date)" >> demo-app/cmd/server/main.go

# Commit and push
git add demo-app/cmd/server/main.go
git commit -m "test: verify CI/CD pipeline"
git push origin main

# Watch:
# - Jenkins: http://localhost:8080 (build should start)
# - ArgoCD: https://localhost:8081 (sync should happen)
# - Pods: kubectl get pods -n demo-app-dev -w
```

**✅ Done! Your CI/CD pipeline is working!**

---

## Architecture Overview

### Complete Flow

```
Developer → Git Push → GitHub
                         ↓
                    [Webhook]
                         ↓
                   JENKINS CI
                         ↓
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
    Checkout         Build            Docker
                                         ↓
                                    Security Scan
                                         ↓
                                    Push Image
                                         ↓
                                 Update Manifests
                                         ↓
                                    Git Commit
                                         ↓
                                   ARGOCD CD
                                         ↓
                    ┌────────────────────┼────────────────┐
                    ↓                    ↓                ↓
              Detect Change         Validate          Apply
                                                          ↓
                                                   KUBERNETES
                                                          ↓
                                                   Rolling Update
                                                          ↓
                                                    MONITORING
```

### Key Components

| Component | Purpose | Namespace | Status |
|-----------|---------|-----------|--------|
| Jenkins | CI - Build, Test, Scan | jenkins | ✅ Running |
| ArgoCD | CD - Deploy, Sync | argocd | ✅ Installed |
| Demo App | Sample application | demo-app-dev | 📦 Ready |
| Prometheus | Metrics collection | monitoring | ✅ Running |
| Grafana | Visualization | monitoring | ✅ Running |

---

## Prerequisites Verification

### Quick Check Script

```bash
#!/bin/bash
echo "=== CI/CD Readiness Check ==="

# Minikube
minikube status | grep -q "Running" && echo "✅ Minikube" || echo "❌ Minikube"

# Jenkins
kubectl get pod -n jenkins jenkins-0 -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running" && echo "✅ Jenkins" || echo "❌ Jenkins"

# ArgoCD
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running" && echo "✅ ArgoCD" || echo "❌ ArgoCD"

# Docker
docker ps >/dev/null 2>&1 && echo "✅ Docker" || echo "❌ Docker"

# Files
[ -f "demo-app/Jenkinsfile" ] && echo "✅ Jenkinsfile" || echo "❌ Jenkinsfile"
[ -d "demo-app/helm-chart/demo-app" ] && echo "✅ Helm Chart" || echo "❌ Helm Chart"
[ -f "argocd/applications/demo-app-dev.yaml" ] && echo "✅ ArgoCD App" || echo "❌ ArgoCD App"

echo "=== Check Complete ==="
```

---

## Jenkins CI Setup

### Your Jenkinsfile Overview

**Location**: `demo-app/Jenkinsfile` (358 lines)

**Stages**:
1. **Checkout** - Clone repository
2. **Build & Test** - Compile Go app, run tests
3. **Docker Build** - Create container image
4. **Security Scan** - Trivy vulnerability scan
5. **Push Image** - Push to Docker registry
6. **Update Manifests** - Update Helm values with new image tag

### Required Credentials

Create these in Jenkins (Manage Jenkins → Credentials):

#### 1. Docker Registry Credentials

```
ID: docker-registry-credentials
Type: Username with password
Username: <dockerhub-username>
Password: <dockerhub-token>
```

Get token: https://hub.docker.com/settings/security

#### 2. Git Credentials

```
ID: git-credentials
Type: Username with password
Username: <github-username>
Password: <github-personal-access-token>
```

Get token: https://github.com/settings/tokens (scopes: repo, workflow)

### Create Pipeline Job

**Via Jenkins UI**:

1. New Item → "demo-app-ci" → Pipeline → OK
2. Configure:
   - Description: "CI pipeline for demo application"
   - Build Triggers: ✓ GitHub hook trigger for GITScm polling
   - Pipeline:
     - Definition: Pipeline script from SCM
     - SCM: Git
     - Repository URL: `https://github.com/YOUR_USERNAME/CKA`
     - Credentials: git-credentials
     - Branch: `*/main`
     - Script Path: `demo-app/Jenkinsfile`
3. Save

### Update Jenkinsfile Variables

Edit `demo-app/Jenkinsfile`:

```groovy
environment {
    APP_NAME = 'demo-app'
    DOCKER_REGISTRY = 'docker.io'  // or your registry
    DOCKER_IMAGE = "${DOCKER_REGISTRY}/YOUR_USERNAME/${APP_NAME}"  // ← Update
    // ... rest of config
}
```

### GitHub Webhook (Optional for Local)

For production:
1. GitHub repo → Settings → Webhooks → Add webhook
2. Payload URL: `http://YOUR_JENKINS_URL/github-webhook/`
3. Content type: application/json
4. Events: Just the push event

For local Minikube, use polling or manual triggers.

---

## ArgoCD CD Setup

### Access ArgoCD

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward
kubectl port-forward -n argocd svc/argocd-server 8081:443

# Open: https://localhost:8081
# Login: admin / <password-from-above>
```

### Configure Git Repository

**Via ArgoCD UI**:
1. Settings (gear icon) → Repositories → Connect Repo
2. Choose: HTTPS
3. Repository URL: `https://github.com/YOUR_USERNAME/CKA`
4. Username: Your GitHub username
5. Password: Your GitHub token
6. Connect

**Via CLI**:
```bash
argocd repo add https://github.com/YOUR_USERNAME/CKA \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

### Create Application

**Update manifest**:
```bash
# Edit argocd/applications/demo-app-dev.yaml
# Change: repoURL: https://github.com/your-username/CKA.git
# To:     repoURL: https://github.com/YOUR_USERNAME/CKA.git

# Apply
kubectl apply -f argocd/applications/demo-app-dev.yaml
```

**Via ArgoCD UI**:
1. New App → Fill in:
   - Application Name: demo-app-dev
   - Project: default
   - Sync Policy: Automatic
   - Repository URL: `https://github.com/YOUR_USERNAME/CKA`
   - Path: `demo-app/helm-chart/demo-app`
   - Cluster URL: `https://kubernetes.default.svc`
   - Namespace: demo-app-dev
   - Helm Values Files: values-dev.yaml
2. Create

### Initial Sync

```bash
# Via UI: Click demo-app-dev → Sync → Synchronize

# Via CLI:
argocd app sync demo-app-dev

# Verify:
kubectl get all -n demo-app-dev
```

---

## GitOps Workflow

### Repository Structure

```
CKA/
├── demo-app/
│   ├── cmd/server/main.go          # Application code
│   ├── Dockerfile                   # Container definition
│   ├── Jenkinsfile                  # CI pipeline ✓
│   └── helm-chart/demo-app/        # Helm chart
│       ├── values.yaml              # Default values
│       ├── values-dev.yaml          # Dev environment ✓
│       └── templates/               # K8s templates
├── argocd/applications/
│   └── demo-app-dev.yaml           # ArgoCD app ✓
└── docs/
    └── CICD-COMPLETE-GUIDE.md      # This file ✓
```

### Complete Workflow Example

```bash
# 1. Developer makes change
vim demo-app/cmd/server/main.go
git add .
git commit -m "feat: add new feature"
git push origin main

# 2. Jenkins CI (Automatic)
#    - Webhook triggers build
#    - Runs all 6 stages
#    - Builds image: demo-app:v125
#    - Updates values-dev.yaml: tag: "v125"
#    - Commits: "chore: update image to v125 [skip ci]"
#    - Pushes to Git

# 3. ArgoCD CD (Automatic)
#    - Detects values-dev.yaml change
#    - Syncs new image tag
#    - Performs rolling update
#    - Monitors health

# 4. Verification
kubectl get pods -n demo-app-dev
# Shows new pods with v125 image

# 5. Rollback (if needed)
#    ArgoCD UI → History → Select previous → Rollback
```

### GitOps Principles

**✅ DO**:
```bash
# Make changes via Git
vim demo-app/helm-chart/demo-app/values-dev.yaml
git commit -m "feat: scale to 5 replicas"
git push
```

**❌ DON'T**:
```bash
# Manual changes (ArgoCD will revert!)
kubectl scale deployment demo-app --replicas=5
```

---

## Testing & Validation

### Test 1: End-to-End Pipeline

```bash
# Make test change
echo "// Test $(date)" >> demo-app/cmd/server/main.go
git add . && git commit -m "test: pipeline" && git push

# Monitor Jenkins
open http://localhost:8080
# Watch build progress in demo-app-ci

# Monitor ArgoCD
open https://localhost:8081
# Watch sync in demo-app-dev

# Verify deployment
kubectl get pods -n demo-app-dev -w
```

### Test 2: Auto-Sync

```bash
# Change replicas
vim demo-app/helm-chart/demo-app/values-dev.yaml
# Change: replicaCount: 3 → 5

git add . && git commit -m "feat: scale to 5" && git push

# Watch ArgoCD auto-sync (within 3 minutes)
watch kubectl get pods -n demo-app-dev
```

### Test 3: Self-Healing

```bash
# Make manual change
kubectl scale deployment demo-app -n demo-app-dev --replicas=10

# ArgoCD detects drift and reverts to Git state (5 replicas)
watch kubectl get pods -n demo-app-dev
```

### Test 4: Rollback

```bash
# Via ArgoCD UI
# 1. Click demo-app-dev
# 2. History and Rollback tab
# 3. Select previous version
# 4. Click Rollback

# Via CLI
argocd app rollback demo-app-dev

# Verify
kubectl get deployment demo-app -n demo-app-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Troubleshooting

### Jenkins Issues

#### Build Fails at Docker Stage

```bash
# Check Docker access
kubectl exec -n jenkins jenkins-0 -- docker ps

# If fails, Jenkins needs Docker socket access
# See: docs/jenkins-crashloop-fix.md
```

#### Credentials Not Found

```bash
# Verify credentials exist
# Jenkins UI → Manage Jenkins → Credentials

# Check IDs match Jenkinsfile:
# - docker-registry-credentials
# - git-credentials
```

#### Git Push Fails

```bash
# Check token has write access
# GitHub → Settings → Developer settings → Personal access tokens
# Scopes needed: repo, workflow
```

### ArgoCD Issues

#### Can't Access Git Repository

```bash
# Test Git access
git clone https://github.com/YOUR_USERNAME/CKA

# Re-add repository in ArgoCD
argocd repo add https://github.com/YOUR_USERNAME/CKA \
  --username YOUR_USERNAME \
  --password YOUR_TOKEN
```

#### Sync Fails

```bash
# Check sync logs
argocd app get demo-app-dev

# View detailed errors
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-application-controller

# Force sync
argocd app sync demo-app-dev --force
```

#### Image Pull Errors

```bash
# For Minikube, load image locally
minikube image load demo-app:latest

# Or use imagePullPolicy: IfNotPresent
kubectl patch deployment demo-app -n demo-app-dev \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"demo-app","imagePullPolicy":"IfNotPresent"}]}}}}'
```

### Common Issues

#### Webhook Not Triggering

```bash
# For local Minikube, use:
# 1. Manual trigger: Click "Build Now" in Jenkins
# 2. Polling: Jenkins checks Git every 5 minutes
# 3. ngrok: Expose Jenkins to internet
```

#### ArgoCD Not Syncing

```bash
# Check sync settings
kubectl get application demo-app-dev -n argocd -o yaml

# Ensure automated sync is enabled:
# syncPolicy:
#   automated:
#     prune: true
#     selfHeal: true
```

---

## Best Practices

### CI/CD Best Practices

1. **Use Semantic Versioning**
   ```bash
   # Tag format: v1.2.3
   git tag -a v1.2.3 -m "Release 1.2.3"
   git push --tags
   ```

2. **Skip CI for Manifest Updates**
   ```bash
   # Jenkins commits with [skip ci]
   git commit -m "chore: update image [skip ci]"
   ```

3. **Separate Environments**
   ```yaml
   # values-dev.yaml, values-staging.yaml, values-prod.yaml
   # Different configs per environment
   ```

4. **Use Helm for Templating**
   ```yaml
   # Easier to manage multiple environments
   # Reusable templates
   # Values override per environment
   ```

### GitOps Best Practices

1. **Git as Single Source of Truth**
   - All changes via Git commits
   - No manual kubectl apply
   - Audit trail in Git history

2. **Declarative Configuration**
   - Describe desired state
   - Let ArgoCD converge to that state

3. **Automated Sync with Caution**
   - Dev/Staging: Automated
   - Production: Manual approval

4. **Monitor and Alert**
   - Set up ArgoCD notifications
   - Monitor sync status
   - Alert on sync failures

### Security Best Practices

1. **Use Secrets Management**
   ```bash
   # Don't commit secrets to Git
   # Use Kubernetes Secrets
   # Or external secret managers (Vault, etc.)
   ```

2. **Scan Images**
   ```bash
   # Trivy scan in Jenkins pipeline
   # Fail build on HIGH/CRITICAL vulnerabilities
   ```

3. **RBAC**
   ```bash
   # Limit ArgoCD permissions
   # Separate service accounts per app
   ```

4. **Network Policies**
   ```yaml
   # Restrict pod-to-pod communication
   # See: demo-app/deployments/kubernetes/06-networkpolicy.yaml
   ```

---

## Summary

### What You Have Now

✅ **Jenkins CI Pipeline**
- Automated builds on Git push
- Unit testing and coverage
- Docker image building
- Security scanning with Trivy
- Image pushing to registry
- Manifest updates via GitOps

✅ **ArgoCD CD Pipeline**
- Automated deployment
- GitOps workflow
- Self-healing
- Rollback capability
- Multi-environment support

✅ **Complete GitOps Workflow**
- Git as single source of truth
- Declarative configuration
- Automated sync
- Audit trail

✅ **Monitoring**
- Prometheus metrics
- Grafana dashboards
- Application health checks

### Next Steps

1. **Customize for Your Needs**
   - Add more test stages
   - Add code quality checks (SonarQube)
   - Add performance tests
   - Add integration tests

2. **Enhance Deployment**
   - Add staging environment
   - Add production environment
   - Implement blue-green deployment
   - Implement canary releases

3. **Improve Monitoring**
   - Create custom Grafana dashboards
   - Set up alerts
   - Add distributed tracing
   - Add log aggregation

4. **Production Readiness**
   - Set up disaster recovery
   - Implement backup strategy
   - Add high availability
   - Document runbooks

---

## Quick Reference

### Access URLs

```bash
# Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080
http://localhost:8080

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8081:443
https://localhost:8081

# Demo App
kubectl port-forward -n demo-app-dev svc/demo-app 8082:80
http://localhost:8082

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
http://localhost:9090

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
http://localhost:3000
```

### Useful Commands

```bash
# Check pipeline status
kubectl get pods -n jenkins
kubectl get application -n argocd
kubectl get pods -n demo-app-dev

# View logs
kubectl logs -n jenkins jenkins-0 -f
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
kubectl logs -n demo-app-dev -l app=demo-app -f

# Trigger sync
argocd app sync demo-app-dev

# Rollback
argocd app rollback demo-app-dev

# Get image version
kubectl get deployment demo-app -n demo-app-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

**🎉 Your CI/CD Pipeline is Ready!**

Make a code change, push to Git, and watch the magic happen! ✨

For detailed explanations, see:
- `demo-app/JENKINSFILE-EXPLAINED.md` (887 lines)
- `argocd/ARGOCD-EXPLAINED.md` (787 lines)
- `docs/jenkins-crashloop-fix.md` (534 lines)
