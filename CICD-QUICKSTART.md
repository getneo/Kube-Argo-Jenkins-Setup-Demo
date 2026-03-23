# CI/CD Quick Start Guide - Local Minikube Setup

> **Your Current Status**: Jenkins ✅ | ArgoCD ✅ | Git Credentials ✅ | Ready to Deploy! 🚀

---

## What You Have

- ✅ Jenkins running in Minikube
- ✅ ArgoCD installed and running
- ✅ Git credentials configured in Jenkins
- ✅ ArgoCD application `demo-app-dev` deployed
- ✅ Local Jenkinsfile created (`demo-app/Jenkinsfile.local`)

## What's Missing (We'll Set Up Now)

- 🔧 Jenkins pipeline job
- 🔧 Initial ArgoCD sync
- 🔧 Demo app deployment

---

## Step 1: Create Jenkins Pipeline Job (5 minutes)

### Access Jenkins

```bash
# Port forward Jenkins (if not already running)
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &

# Open in browser
open http://localhost:8080
```

### Create Pipeline Job

1. **Click "New Item"**
2. **Enter name**: `demo-app-ci-local`
3. **Select**: "Pipeline"
4. **Click "OK"**

5. **Configure the job**:

   **General Section**:
   - Description: `CI pipeline for demo app (local Minikube)`
   - ✓ Discard old builds: Max # of builds to keep: `10`

   **Build Triggers** (Optional for now):
   - ✓ Poll SCM: `H/5 * * * *` (checks every 5 minutes)

   **Pipeline Section**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/niravsoni/CKA`
   - Credentials: `git-credentials` (select from dropdown)
   - Branch Specifier: `*/main`
   - Script Path: `demo-app/Jenkinsfile.local`

6. **Click "Save"**

---

## Step 2: Sync ArgoCD Application (2 minutes)

### Access ArgoCD

```bash
# Port forward ArgoCD (if not already running)
kubectl port-forward -n argocd svc/argocd-server 8081:443 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Open in browser
open https://localhost:8081
# Login: admin / <password-from-above>
```

### Sync the Application

1. **Click on "demo-app-dev"** application
2. **Click "Sync"** button (top right)
3. **Sync Options**:
   - ✓ Prune: Delete resources not in Git
   - ✓ Apply Only: Don't wait for health check (for faster first sync)
4. **Click "Synchronize"**

### Watch the Sync

You'll see:
- Creating namespace `demo-app-dev`
- Creating ConfigMap
- Creating Deployment
- Creating Service
- Creating HPA
- etc.

Wait for:
- **Sync Status**: Synced ✓
- **Health Status**: Healthy ✓

---

## Step 3: Verify Deployment (2 minutes)

```bash
# Check namespace
kubectl get namespace demo-app-dev

# Check all resources
kubectl get all -n demo-app-dev

# Check pods
kubectl get pods -n demo-app-dev

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# demo-app-7d9f8b6c5d-xxxxx   1/1     Running   0          1m
# demo-app-7d9f8b6c5d-yyyyy   1/1     Running   0          1m
# demo-app-7d9f8b6c5d-zzzzz   1/1     Running   0          1m
```

### Test the Application

```bash
# Port forward to the service
kubectl port-forward -n demo-app-dev svc/demo-app 8082:80 &

# Test health endpoint
curl http://localhost:8082/health

# Expected output:
# {"status":"healthy","timestamp":"2026-03-23T..."}

# Test root endpoint
curl http://localhost:8082/

# Expected output:
# {"message":"Hello from Demo App!","version":"1.0.0"}
```

---

## Step 4: Test the CI/CD Pipeline (5 minutes)

### Option A: Manual Trigger (Fastest)

```bash
# In Jenkins UI:
# 1. Click on "demo-app-ci-local"
# 2. Click "Build Now"
# 3. Watch the build progress
# 4. Click on build #1 → Console Output
```

### Option B: Code Change (Full GitOps)

```bash
# Make a simple change
echo "// Pipeline test $(date)" >> demo-app/cmd/server/main.go

# Commit and push
git add demo-app/cmd/server/main.go
git commit -m "test: verify CI/CD pipeline"
git push origin main

# Jenkins will:
# 1. Detect the push (if polling enabled) or trigger manually
# 2. Build the Go app
# 3. Create Docker image in Minikube
# 4. Update Helm values with new image tag
# 5. Push changes to Git

# ArgoCD will:
# 1. Detect the Helm values change
# 2. Sync the new image tag
# 3. Perform rolling update
# 4. Monitor health
```

### Watch the Pipeline

**Jenkins**:
```bash
# Open: http://localhost:8080
# Navigate to: demo-app-ci-local → Build #1
# Watch stages complete:
# ✓ Checkout
# ✓ Build & Test
# ✓ Docker Build
# ✓ Security Scan (if Trivy installed)
# ✓ Load to Minikube
# ✓ Update Manifests
```

**ArgoCD**:
```bash
# Open: https://localhost:8081
# Click: demo-app-dev
# Watch sync status change:
# OutOfSync → Syncing → Synced ✓
```

**Kubernetes**:
```bash
# Watch pods update
kubectl get pods -n demo-app-dev -w

# You'll see:
# - New pods creating
# - Old pods terminating
# - Rolling update in progress
```

---

## Troubleshooting

### Jenkins Build Fails

#### Issue: "Docker not found"

```bash
# Jenkins needs access to Minikube's Docker
# This is handled in Jenkinsfile.local with: eval $(minikube docker-env)
```

#### Issue: "Git push fails"

```bash
# Check git-credentials in Jenkins
# Ensure GitHub token has 'repo' and 'workflow' scopes
```

#### Issue: "Go not found"

```bash
# Install Go in Jenkins pod
kubectl exec -n jenkins jenkins-0 -- which go

# If not found, you may need to install Go
# Or use a Jenkins agent with Go pre-installed
```

### ArgoCD Sync Fails

#### Issue: "Repository not accessible"

```bash
# Re-add repository in ArgoCD
# Settings → Repositories → Connect Repo
# URL: https://github.com/niravsoni/CKA
# Use your GitHub credentials
```

#### Issue: "Sync status stuck"

```bash
# Force sync
kubectl patch application demo-app-dev -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or in ArgoCD UI: Click Sync → Force
```

### Application Issues

#### Issue: "Pods not starting"

```bash
# Check pod logs
kubectl logs -n demo-app-dev -l app=demo-app

# Check events
kubectl get events -n demo-app-dev --sort-by='.lastTimestamp'

# Common issues:
# - Image not found: Build failed or image not in Minikube
# - CrashLoopBackOff: Application error, check logs
```

#### Issue: "Image pull errors"

```bash
# For local Minikube, ensure imagePullPolicy is correct
kubectl get deployment demo-app -n demo-app-dev -o yaml | grep imagePullPolicy

# Should be: imagePullPolicy: IfNotPresent or Never
```

---

## Useful Commands

### Jenkins

```bash
# Port forward
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Check Jenkins pod
kubectl get pod -n jenkins jenkins-0

# View Jenkins logs
kubectl logs -n jenkins jenkins-0 -f

# Restart Jenkins
kubectl delete pod -n jenkins jenkins-0
```

### ArgoCD

```bash
# Port forward
kubectl port-forward -n argocd svc/argocd-server 8081:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Check application status
kubectl get application -n argocd demo-app-dev

# Sync application
kubectl patch application demo-app-dev -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# View ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

### Demo App

```bash
# Check pods
kubectl get pods -n demo-app-dev

# Check deployment
kubectl get deployment demo-app -n demo-app-dev

# Check service
kubectl get svc demo-app -n demo-app-dev

# Port forward
kubectl port-forward -n demo-app-dev svc/demo-app 8082:80

# Test application
curl http://localhost:8082/health
curl http://localhost:8082/

# View logs
kubectl logs -n demo-app-dev -l app=demo-app -f

# Get image version
kubectl get deployment demo-app -n demo-app-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Minikube

```bash
# Check status
minikube status

# Access Minikube Docker
eval $(minikube docker-env)
docker images | grep demo-app

# Reset Minikube Docker env
eval $(minikube docker-env -u)
```

---

## Next Steps

### 1. Customize the Pipeline

Edit `demo-app/Jenkinsfile.local` to:
- Add more test stages
- Add code quality checks
- Add integration tests
- Customize notifications

### 2. Add More Environments

Create additional ArgoCD applications:
```bash
# Staging
cp argocd/applications/demo-app-dev.yaml \
   argocd/applications/demo-app-staging.yaml

# Edit and change:
# - name: demo-app-staging
# - namespace: demo-app-staging
# - valueFiles: values-staging.yaml

# Production
cp argocd/applications/demo-app-dev.yaml \
   argocd/applications/demo-app-prod.yaml

# Edit and change:
# - name: demo-app-prod
# - namespace: demo-app-prod
# - valueFiles: values-prod.yaml
# - syncPolicy: manual (for production)
```

### 3. Set Up Monitoring

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open: http://localhost:3000
# Login: admin / prom-operator (default)

# Import dashboards for:
# - Kubernetes cluster metrics
# - Application metrics
# - CI/CD pipeline metrics
```

### 4. Enable Notifications

Configure ArgoCD notifications:
- Slack
- Email
- Webhook

Configure Jenkins notifications:
- Email
- Slack
- GitHub status checks

---

## Summary

You now have:
- ✅ Jenkins CI pipeline building and testing code
- ✅ Docker images built in Minikube
- ✅ ArgoCD CD pipeline deploying to Kubernetes
- ✅ GitOps workflow (Git as source of truth)
- ✅ Automated sync and self-healing
- ✅ Complete CI/CD pipeline working locally!

**Make a code change, push to Git, and watch it deploy automatically!** 🚀

---

## Quick Reference

| Service | URL | Credentials |
|---------|-----|-------------|
| Jenkins | http://localhost:8080 | admin / <your-password> |
| ArgoCD | https://localhost:8081 | admin / <get-from-secret> |
| Demo App | http://localhost:8082 | N/A |
| Prometheus | http://localhost:9090 | N/A |
| Grafana | http://localhost:3000 | admin / prom-operator |

**Port Forwards**:
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &
kubectl port-forward -n argocd svc/argocd-server 8081:443 &
kubectl port-forward -n demo-app-dev svc/demo-app 8082:80 &
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
kubectl port-forward -n monitoring svc/grafana 3000:80 &
```

---

**Need help?** Check:
- `docs/CICD-COMPLETE-GUIDE.md` - Complete guide
- `docs/jenkins-crashloop-fix.md` - Jenkins troubleshooting
- `argocd/ARGOCD-EXPLAINED.md` - ArgoCD deep dive
- `demo-app/JENKINSFILE-EXPLAINED.md` - Jenkinsfile details
