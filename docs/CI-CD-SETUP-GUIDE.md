# CI/CD Setup Guide - Complete Walkthrough

This guide will walk you through setting up a complete CI/CD pipeline using Jenkins (CI) and ArgoCD (CD) for the demo application.

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Part 1: Jenkins CI Pipeline](#part-1-jenkins-ci-pipeline)
5. [Part 2: ArgoCD CD Pipeline](#part-2-argocd-cd-pipeline)
6. [Part 3: GitOps Workflow](#part-3-gitops-workflow)
7. [Part 4: Testing the Pipeline](#part-4-testing-the-pipeline)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### What We're Building

```
Developer Push → GitHub → Jenkins (CI) → Docker Registry → ArgoCD (CD) → Kubernetes
                    ↓                          ↓                ↓
                  Build                    Push Image      Deploy App
                  Test                     Update Manifest  Monitor
                  Scan                                      Sync
```

### Components

1. **Jenkins (CI)**:
   - Builds Docker images
   - Runs tests
   - Scans for vulnerabilities
   - Pushes images to registry
   - Updates Kubernetes manifests

2. **ArgoCD (CD)**:
   - Monitors Git repository
   - Syncs Kubernetes state
   - Deploys applications
   - Provides rollback capability

3. **Git Repository**:
   - Source code
   - Kubernetes manifests
   - Helm charts
   - Pipeline definitions

---

## Architecture

### CI/CD Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Developer                                │
│                              ↓                                   │
│                    git push to GitHub                            │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Webhook                                │
│                              ↓                                   │
│                    Triggers Jenkins                              │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Jenkins CI Pipeline                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Stage 1: Checkout                                        │  │
│  │   - Clone repository                                     │  │
│  │   - Checkout branch                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                               ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Stage 2: Build                                           │  │
│  │   - Build Go application                                 │  │
│  │   - Run unit tests                                       │  │
│  │   - Generate coverage report                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                               ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Stage 3: Docker Build                                    │  │
│  │   - Build Docker image                                   │  │
│  │   - Tag with version                                     │  │
│  │   - Tag with commit SHA                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                               ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Stage 4: Security Scan                                   │  │
│  │   - Scan with Trivy                                      │  │
│  │   - Check for vulnerabilities                            │  │
│  │   - Generate report                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                               ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Stage 5: Push Image                                      │  │
│  │   - Login to registry                                    │  │
│  │   - Push Docker image                                    │  │
│  │   - Push all tags                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                               ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Stage 6: Update Manifests                                │  │
│  │   - Update image tag in manifests                        │  │
│  │   - Commit changes                                       │  │
│  │   - Push to Git                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Git Repository Updated                        │
│                              ↓                                   │
│                    ArgoCD Detects Change                         │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                    ArgoCD CD Pipeline                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Step 1: Sync Detection                                   │  │
│  │   - Compare Git vs Cluster                               │  │
│  │   - Identify differences                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                               ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Step 2: Sync Execution                                   │  │
│  │   - Apply Kubernetes manifests                           │  │
│  │   - Update deployments                                   │  │
│  │   - Wait for rollout                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                               ↓                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Step 3: Health Check                                     │  │
│  │   - Check pod status                                     │  │
│  │   - Verify health probes                                 │  │
│  │   - Monitor metrics                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Application Running                           │
│                              ↓                                   │
│                    Prometheus Monitoring                         │
│                              ↓                                   │
│                    Grafana Dashboards                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Tools

Check if you have these installed:

```bash
# 1. Kubernetes cluster (Minikube)
minikube status

# 2. kubectl
kubectl version --client

# 3. Helm
helm version

# 4. Docker
docker --version

# 5. Git
git --version
```

### Required Services

Ensure these are running:

```bash
# 1. Jenkins
kubectl get pods -n jenkins

# 2. ArgoCD
kubectl get pods -n argocd

# 3. Prometheus/Grafana
kubectl get pods -n monitoring
```

If any service is not running, refer to the setup guides in the `docs/` directory.

---

## Part 1: Jenkins CI Pipeline

### Step 1.1: Understand the Jenkinsfile

I'll create a `Jenkinsfile` that defines the CI pipeline. Let me explain each section:

**File Location**: `demo-app/Jenkinsfile`

**Purpose**: Defines the automated build, test, and deployment process.

**Structure**:
```groovy
pipeline {
    agent any              // Run on any available Jenkins agent

    environment {          // Define environment variables
        // Variables used throughout the pipeline
    }

    stages {              // Define pipeline stages
        stage('Checkout') { ... }
        stage('Build') { ... }
        stage('Docker Build') { ... }
        stage('Security Scan') { ... }
        stage('Push Image') { ... }
        stage('Update Manifests') { ... }
    }

    post {                // Actions after pipeline completion
        always { ... }    // Always run
        success { ... }   // Run on success
        failure { ... }   // Run on failure
    }
}
```

### Step 1.2: Create Jenkins Credentials

Before running the pipeline, you need to create credentials in Jenkins:

```bash
# 1. Access Jenkins UI
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# 2. Open browser: http://localhost:8080

# 3. Navigate to: Manage Jenkins → Manage Credentials → Global → Add Credentials

# 4. Create these credentials:
```

**Credential 1: Docker Registry**
- Kind: Username with password
- ID: `docker-registry-credentials`
- Username: Your Docker Hub username
- Password: Your Docker Hub password or access token
- Description: Docker Hub credentials

**Credential 2: Git Credentials**
- Kind: Username with password (or SSH key)
- ID: `git-credentials`
- Username: Your GitHub username
- Password: Your GitHub personal access token
- Description: GitHub credentials

**Credential 3: Kubeconfig**
- Kind: Secret file
- ID: `kubeconfig`
- File: Upload your kubeconfig file
- Description: Kubernetes config

### Step 1.3: Create Jenkins Pipeline Job

```bash
# 1. In Jenkins UI, click "New Item"
# 2. Enter name: "demo-app-ci"
# 3. Select: "Pipeline"
# 4. Click "OK"

# 5. Configure the pipeline:
#    - Description: "CI pipeline for demo application"
#    - Build Triggers: Check "GitHub hook trigger for GITScm polling"
#    - Pipeline:
#      - Definition: "Pipeline script from SCM"
#      - SCM: Git
#      - Repository URL: https://github.com/YOUR_USERNAME/CKA
#      - Credentials: Select git-credentials
#      - Branch: */main
#      - Script Path: demo-app/Jenkinsfile

# 6. Click "Save"
```

### Step 1.4: Configure GitHub Webhook

```bash
# 1. Go to your GitHub repository
# 2. Settings → Webhooks → Add webhook
# 3. Payload URL: http://YOUR_JENKINS_URL/github-webhook/
# 4. Content type: application/json
# 5. Events: Just the push event
# 6. Active: ✓
# 7. Add webhook
```

---

## Part 2: ArgoCD CD Pipeline

### Step 2.1: Understand ArgoCD Application

ArgoCD uses an `Application` resource to define what to deploy and where.

**File Location**: `argocd/demo-app-application.yaml`

**Purpose**: Tells ArgoCD:
- Where is the source (Git repo)
- What to deploy (Helm chart or manifests)
- Where to deploy (Kubernetes cluster/namespace)
- How to sync (automatic or manual)

**Structure**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app              # Application name
  namespace: argocd           # ArgoCD namespace
spec:
  project: default            # ArgoCD project

  source:                     # Where to get manifests
    repoURL: ...              # Git repository
    targetRevision: main      # Branch/tag
    path: ...                 # Path to manifests

  destination:                # Where to deploy
    server: ...               # Kubernetes API server
    namespace: demo-app       # Target namespace

  syncPolicy:                 # How to sync
    automated:                # Auto-sync enabled
      prune: true            # Delete removed resources
      selfHeal: true         # Auto-correct drift
```

### Step 2.2: Access ArgoCD UI

```bash
# 1. Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 2. Port forward to ArgoCD server
kubectl port-forward -n argocd svc/argocd-server 8081:443

# 3. Open browser: https://localhost:8081
#    Username: admin
#    Password: (from step 1)

# 4. Accept self-signed certificate warning
```

### Step 2.3: Configure Git Repository in ArgoCD

```bash
# Option 1: Via UI
# 1. In ArgoCD UI: Settings → Repositories → Connect Repo
# 2. Choose connection method: HTTPS
# 3. Repository URL: https://github.com/YOUR_USERNAME/CKA
# 4. Username: Your GitHub username
# 5. Password: Your GitHub personal access token
# 6. Click "Connect"

# Option 2: Via CLI
argocd repo add https://github.com/YOUR_USERNAME/CKA \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

### Step 2.4: Create ArgoCD Application

```bash
# Option 1: Via UI
# 1. Click "New App"
# 2. Fill in details (see Application YAML for values)
# 3. Click "Create"

# Option 2: Via CLI
kubectl apply -f argocd/demo-app-application.yaml

# Option 3: Via ArgoCD CLI
argocd app create demo-app \
  --repo https://github.com/YOUR_USERNAME/CKA \
  --path demo-app/helm-chart/demo-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace demo-app \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

---

## Part 3: GitOps Workflow

### Step 3.1: Repository Structure

Your repository should be organized like this:

```
CKA/
├── demo-app/                    # Application code
│   ├── cmd/                     # Go application
│   ├── internal/
│   ├── pkg/
│   ├── Dockerfile               # Docker build
│   ├── Jenkinsfile             # CI pipeline
│   ├── deployments/
│   │   └── kubernetes/         # Raw manifests
│   └── helm-chart/
│       └── demo-app/           # Helm chart (ArgoCD uses this)
│           ├── Chart.yaml
│           ├── values.yaml
│           ├── values-dev.yaml
│           ├── values-prod.yaml
│           └── templates/
├── argocd/                     # ArgoCD configurations
│   ├── demo-app-application.yaml
│   ├── projects/
│   └── app-of-apps/
├── jenkins/                    # Jenkins configurations
│   └── values.yaml
└── docs/                       # Documentation
```

### Step 3.2: GitOps Principles

**1. Git as Single Source of Truth**
- All configuration in Git
- No manual kubectl apply
- All changes via Git commits

**2. Declarative Configuration**
- Describe desired state
- System converges to that state
- No imperative commands

**3. Automated Sync**
- ArgoCD monitors Git
- Automatically applies changes
- Self-healing on drift

**4. Version Control**
- All changes tracked
- Easy rollback
- Audit trail

### Step 3.3: Workflow Example

**Scenario**: Update application to version 1.1.0

```bash
# 1. Developer makes code changes
cd demo-app
vim cmd/server/main.go

# 2. Commit and push
git add .
git commit -m "feat: add new feature for v1.1.0"
git push origin main

# 3. Jenkins CI Pipeline (Automatic)
#    - Detects push via webhook
#    - Builds application
#    - Runs tests
#    - Builds Docker image: demo-app:1.1.0
#    - Scans for vulnerabilities
#    - Pushes to Docker registry
#    - Updates helm-chart/demo-app/values.yaml:
#      image:
#        tag: "1.1.0"
#    - Commits and pushes change

# 4. ArgoCD CD Pipeline (Automatic)
#    - Detects values.yaml change
#    - Compares with cluster state
#    - Syncs new image tag
#    - Performs rolling update
#    - Monitors health checks
#    - Reports success

# 5. Verification
kubectl get pods -n demo-app
# Shows new pods with v1.1.0

# 6. Rollback (if needed)
#    Option A: Via ArgoCD UI
#    - Click "History and Rollback"
#    - Select previous version
#    - Click "Rollback"
#  
#    Option B: Via Git
#    git revert HEAD
#    git push origin main
```

---

## Part 4: Testing the Pipeline

### Step 4.1: End-to-End Test

Let's test the complete CI/CD pipeline:

```bash
# 1. Make a simple change
cd demo-app
echo "// Test change" >> cmd/server/main.go

# 2. Commit and push
git add cmd/server/main.go
git commit -m "test: trigger CI/CD pipeline"
git push origin main

# 3. Watch Jenkins build
# Open Jenkins UI: http://localhost:8080
# Click on "demo-app-ci"
# Watch the build progress

# 4. Watch ArgoCD sync
# Open ArgoCD UI: https://localhost:8081
# Click on "demo-app"
# Watch the sync status

# 5. Verify deployment
kubectl get pods -n demo-app -w

# 6. Check application
kubectl port-forward -n demo-app svc/demo-app 8080:80
curl http://localhost:8080/health
```

### Step 4.2: Monitor the Pipeline

**Jenkins Monitoring**:
```bash
# View build logs
# In Jenkins UI: demo-app-ci → Build #X → Console Output

# Check build status
# Green: Success ✓
# Red: Failure ✗
# Blue: In progress ⟳
```

**ArgoCD Monitoring**:
```bash
# View sync status
# In ArgoCD UI: Applications → demo-app

# Sync States:
# - Synced: Git matches cluster ✓
# - OutOfSync: Differences detected
# - Progressing: Sync in progress ⟳

# Health States:
# - Healthy: All resources healthy ✓
# - Degraded: Some resources unhealthy ✗
# - Progressing: Deployment in progress ⟳
```

### Step 4.3: Test Rollback

```bash
# 1. Note current version
kubectl get deployment -n demo-app demo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# 2. Trigger rollback in ArgoCD UI
# Applications → demo-app → History and Rollback
# Select previous revision → Rollback

# 3. Verify rollback
kubectl get pods -n demo-app -w
# Watch pods restart with previous version

# 4. Confirm version
kubectl get deployment -n demo-app demo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Troubleshooting

### Issue 1: Jenkins Build Fails

**Symptom**: Build fails at Docker build stage

**Solution**:
```bash
# Check Docker daemon
docker ps

# Check Jenkins pod has Docker socket
kubectl exec -n jenkins jenkins-0 -- docker ps

# Verify credentials
# Jenkins UI → Credentials → Check docker-registry-credentials
```

### Issue 2: ArgoCD Can't Access Git

**Symptom**: "repository not accessible"

**Solution**:
```bash
# Test Git access
git clone https://github.com/YOUR_USERNAME/CKA

# Check ArgoCD repository
argocd repo list

# Re-add repository
argocd repo add https://github.com/YOUR_USERNAME/CKA \
  --username YOUR_USERNAME \
  --password YOUR_TOKEN
```

### Issue 3: Image Pull Errors

**Symptom**: Pods show ImagePullBackOff

**Solution**:
```bash
# Check image exists
docker pull demo-app:latest

# For Minikube, load image
minikube image load demo-app:latest

# Or use imagePullPolicy: IfNotPresent
kubectl patch deployment demo-app -n demo-app \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"demo-app","imagePullPolicy":"IfNotPresent"}]}}}}'
```

### Issue 4: ArgoCD Sync Fails

**Symptom**: Sync status shows "Failed"

**Solution**:
```bash
# Check sync logs
argocd app get demo-app

# View detailed errors
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Manual sync
argocd app sync demo-app --force
```

### Issue 5: Webhook Not Triggering

**Symptom**: Push to Git doesn't trigger Jenkins

**Solution**:
```bash
# Check webhook in GitHub
# Settings → Webhooks → Recent Deliveries

# Test webhook
# Click "Redeliver"

# Check Jenkins webhook URL
# Should be: http://YOUR_JENKINS_URL/github-webhook/

# Verify Jenkins is accessible from internet
# Or use ngrok for local testing:
ngrok http 8080
# Update webhook URL to ngrok URL
```

---

## Next Steps

After completing this setup:

1. **Customize the Pipeline**:
   - Add more test stages
   - Add code quality checks
   - Add security scanning
   - Add deployment to multiple environments

2. **Enhance ArgoCD**:
   - Create multiple applications (dev, staging, prod)
   - Set up App of Apps pattern
   - Configure notifications
   - Set up SSO

3. **Add Monitoring**:
   - Integrate with Prometheus
   - Create Grafana dashboards
   - Set up alerts
   - Monitor pipeline metrics

4. **Implement Best Practices**:
   - Use Helm for all deployments
   - Implement blue-green deployments
   - Add canary releases
   - Set up disaster recovery

---

## Summary

You now have:
- ✅ Jenkins CI pipeline for building and testing
- ✅ ArgoCD CD pipeline for deployment
- ✅ GitOps workflow for infrastructure as code
- ✅ Automated sync and self-healing
- ✅ Rollback capability
- ✅ Complete monitoring and observability

**The pipeline is ready to use!** 🚀

Make a code change, push to Git, and watch the magic happen! ✨
