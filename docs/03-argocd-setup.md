# 03 - ArgoCD Setup on Kubernetes

## Overview

This guide covers the installation and configuration of ArgoCD on Kubernetes for GitOps-based continuous deployment. ArgoCD automates application deployment and lifecycle management by continuously monitoring Git repositories and synchronizing the desired state with the cluster.

---

## Architecture

```mermaid
graph TB
    subgraph "ArgoCD Namespace"
        SERVER[ArgoCD Server]
        REPO[Repo Server]
        CONTROLLER[Application Controller]
        REDIS[Redis Cache]
        DEX[Dex SSO - Optional]

        SERVER -->|Queries| REDIS
        SERVER -->|Manages| CONTROLLER
        CONTROLLER -->|Fetches| REPO
    end

    subgraph "Git Repository"
        MANIFESTS[K8s Manifests]
        HELM[Helm Charts]
        KUSTOMIZE[Kustomize Overlays]
    end

    subgraph "Target Namespaces"
        APP1[Demo App]
        APP2[Monitoring]
        APP3[Other Apps]
    end

    subgraph "External Access"
        USER[Developer]
        CLI[ArgoCD CLI]
        UI[Web UI]
    end

    REPO -->|Clones| MANIFESTS
    REPO -->|Clones| HELM
    REPO -->|Clones| KUSTOMIZE
    CONTROLLER -->|Deploys| APP1
    CONTROLLER -->|Deploys| APP2
    CONTROLLER -->|Deploys| APP3
    USER -->|Access| UI
    USER -->|Commands| CLI
    UI -->|API| SERVER
    CLI -->|API| SERVER
```

### Key Features

- ✅ **GitOps Workflow**: Git as single source of truth
- ✅ **Automated Sync**: Continuous reconciliation
- ✅ **Multi-Source Support**: Helm, Kustomize, plain YAML
- ✅ **RBAC**: Fine-grained access control
- ✅ **SSO Integration**: OIDC, SAML, LDAP support
- ✅ **Health Assessment**: Application health monitoring
- ✅ **Rollback**: Easy rollback to previous versions
- ✅ **Sync Waves**: Ordered resource deployment

---

## Prerequisites

- Minikube cluster running
- kubectl configured
- `argocd` namespace created
- Git repository for manifests (can be this repo)
- Minimum 1GB RAM and 1 CPU core available

### Verify Prerequisites

```bash
# Check cluster
kubectl cluster-info

# Check namespace
kubectl get namespace argocd

# Check available resources
kubectl top nodes
```

---

## 1. Install ArgoCD

### 1.1 Install ArgoCD Core Components

```bash
# Install ArgoCD using official manifests
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD (stable version)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Expected output:
# pod/argocd-server-xxxxxxxxxx-xxxxx condition met
```

### 1.2 Verify Installation

```bash
# Check all ArgoCD pods
kubectl get pods -n argocd

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0       1/1     Running   0          2m
# argocd-applicationset-controller-xxx  1/1     Running   0          2m
# argocd-dex-server-xxx                 1/1     Running   0          2m
# argocd-notifications-controller-xxx   1/1     Running   0          2m
# argocd-redis-xxx                      1/1     Running   0          2m
# argocd-repo-server-xxx                1/1     Running   0          2m
# argocd-server-xxx                     1/1     Running   0          2m

# Check services
kubectl get svc -n argocd

# Check configmaps
kubectl get cm -n argocd
```

---

## 2. Install ArgoCD CLI

### 2.1 Install on macOS

```bash
# Install using Homebrew
brew install argocd

# Verify installation
argocd version --client

# Expected output:
# argocd: v2.x.x+xxxxxxx
```

### 2.2 Alternative Installation Methods

```bash
# Download binary directly
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-darwin-amd64
chmod +x /usr/local/bin/argocd

# For Apple Silicon (M1/M2)
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-darwin-arm64
chmod +x /usr/local/bin/argocd
```

---

## 3. Access ArgoCD

### 3.1 Get Initial Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Save this password for initial login
# Username: admin
# Password: [output from above command]
```

### 3.2 Access via Port Forward

```bash
# Forward ArgoCD server port to localhost
kubectl port-forward svc/argocd-server -n argocd 8443:443

# Access ArgoCD UI at: https://localhost:8443
# Username: admin
# Password: [from previous step]

# Note: You'll see a certificate warning - this is expected for local development
```

### 3.3 Access via Ingress

Create `argocd/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
    - host: argocd.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  name: https
```

Apply ingress:

```bash
# Apply ingress configuration
kubectl apply -f argocd/ingress.yaml

# Add to /etc/hosts
echo "$(minikube ip) argocd.local" | sudo tee -a /etc/hosts

# Access at: https://argocd.local
```

### 3.4 Login via CLI

```bash
# Login to ArgoCD via CLI
argocd login localhost:8443 --username admin --password <initial-password> --insecure

# Or with port-forward running
argocd login localhost:8443 --insecure

# Expected output:
# 'admin:login' logged in successfully
```

---

## 4. Configure ArgoCD

### 4.1 Change Admin Password

```bash
# Change admin password via CLI
argocd account update-password

# Or via UI: User Info → Update Password
```

### 4.2 Configure ArgoCD Server

Create `argocd/argocd-cm.yaml` for custom configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  # Enable anonymous access (for demo only - disable in production)
  # users.anonymous.enabled: "false"

  # Application instance label key
  application.instanceLabelKey: argocd.argoproj.io/instance

  # Timeout settings
  timeout.reconciliation: 180s
  timeout.hard.reconciliation: 0s

  # Resource customizations
  resource.customizations: |
    admissionregistration.k8s.io/MutatingWebhookConfiguration:
      ignoreDifferences: |
        jsonPointers:
        - /webhooks/0/clientConfig/caBundle
    admissionregistration.k8s.io/ValidatingWebhookConfiguration:
      ignoreDifferences: |
        jsonPointers:
        - /webhooks/0/clientConfig/caBundle

  # Repository credentials template
  repository.credentials: |
    - url: https://github.com/your-org
      passwordSecret:
        name: github-secret
        key: password
      usernameSecret:
        name: github-secret
        key: username

  # Kustomize build options
  kustomize.buildOptions: --enable-helm

  # Helm repositories
  helm.repositories: |
    - url: https://charts.bitnami.com/bitnami
      name: bitnami
    - url: https://prometheus-community.github.io/helm-charts
      name: prometheus-community
    - url: https://grafana.github.io/helm-charts
      name: grafana
```

Apply configuration:

```bash
kubectl apply -f argocd/argocd-cm.yaml
```

### 4.3 Configure RBAC

Create `argocd/argocd-rbac-cm.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  # Default policy
  policy.default: role:readonly

  # CSV format for RBAC policies
  policy.csv: |
    # Admin role - full access
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, certificates, *, *, allow
    p, role:admin, gpgkeys, *, *, allow

    # Developer role - can manage applications
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, create, */*, allow
    p, role:developer, applications, update, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, delete, */*, allow
    p, role:developer, repositories, get, *, allow
    p, role:developer, projects, get, *, allow

    # Readonly role - view only
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, repositories, get, *, allow
    p, role:readonly, projects, get, *, allow
    p, role:readonly, clusters, get, *, allow

    # CI/CD role - for automation
    p, role:cicd, applications, sync, */*, allow
    p, role:cicd, applications, get, */*, allow

    # Grant admin role to admin user
    g, admin, role:admin

  # Scopes for SSO (if using)
  scopes: '[groups, email]'
```

Apply RBAC configuration:

```bash
kubectl apply -f argocd/argocd-rbac-cm.yaml
```

---

## 5. Add Git Repository

### 5.1 Add Public Repository

```bash
# Add public Git repository
argocd repo add https://github.com/your-username/your-repo.git

# Verify
argocd repo list
```

### 5.2 Add Private Repository (HTTPS)

```bash
# Create secret for Git credentials
kubectl create secret generic github-secret \
  --from-literal=username=your-username \
  --from-literal=password=your-token \
  -n argocd

# Add private repository via CLI
argocd repo add https://github.com/your-username/private-repo.git \
  --username your-username \
  --password your-token

# Or add via declarative config
```

Create `argocd/repository-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/your-username/private-repo.git
  username: your-username
  password: your-token-or-password
```

Apply:

```bash
kubectl apply -f argocd/repository-secret.yaml
```

### 5.3 Add Private Repository (SSH)

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "argocd@example.com" -f ~/.ssh/argocd_ed25519

# Add public key to GitHub/GitLab
cat ~/.ssh/argocd_ed25519.pub

# Create secret with private key
kubectl create secret generic github-ssh-key \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd_ed25519 \
  -n argocd

# Add repository
argocd repo add git@github.com:your-username/private-repo.git \
  --ssh-private-key-path ~/.ssh/argocd_ed25519
```

---

## 6. Create ArgoCD Projects

### 6.1 Create Default Project

Create `argocd/project.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: default
  namespace: argocd
  # Finalizer ensures project is not deleted if apps exist
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: Default project for all applications

  # Source repositories
  sourceRepos:
    - '*'  # Allow all repositories

  # Destination clusters and namespaces
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc

  # Cluster resource whitelist
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'

  # Namespace resource whitelist
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'

  # Orphaned resources monitoring
  orphanedResources:
    warn: true
```

### 6.2 Create Environment-Specific Projects

Create `argocd/project-dev.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: development
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: Development environment applications

  sourceRepos:
    - https://github.com/your-org/k8s-manifests.git

  destinations:
    - namespace: demo-app
      server: https://kubernetes.default.svc
    - namespace: dev-*
      server: https://kubernetes.default.svc

  clusterResourceWhitelist:
    - group: ''
      kind: Namespace

  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'

  roles:
    - name: developer
      description: Developer access to development apps
      policies:
        - p, proj:development:developer, applications, *, development/*, allow
      groups:
        - developers
```

Apply projects:

```bash
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/project-dev.yaml

# Verify
argocd proj list
```

---

## 7. Create ArgoCD Applications

### 7.1 Create Application via CLI

```bash
# Create application for demo app
argocd app create demo-app \
  --repo https://github.com/your-username/your-repo.git \
  --path k8s/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace demo-app \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Verify
argocd app list
argocd app get demo-app
```

### 7.2 Create Application Declaratively

Create `argocd/application-demo.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
  # Finalizer ensures cascade delete
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  # Project the application belongs to
  project: default

  # Source repository
  source:
    repoURL: https://github.com/your-username/your-repo.git
    targetRevision: main
    path: k8s/overlays/dev

    # For Kustomize
    kustomize:
      namePrefix: dev-
      commonLabels:
        environment: development
      images:
        - your-image:tag

    # For Helm (alternative)
    # helm:
    #   releaseName: demo-app
    #   valueFiles:
    #     - values-dev.yaml
    #   parameters:
    #     - name: image.tag
    #       value: v1.0.0

  # Destination cluster and namespace
  destination:
    server: https://kubernetes.default.svc
    namespace: demo-app

  # Sync policy
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Sync when cluster state differs
      allowEmpty: false

    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true

    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  # Ignore differences
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas

  # Health assessment
  revisionHistoryLimit: 10
```

Apply application:

```bash
kubectl apply -f argocd/application-demo.yaml

# Watch sync status
argocd app get demo-app --watch

# Sync manually if needed
argocd app sync demo-app
```

### 7.3 Create Application with Helm

Create `argocd/application-helm.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: default

  source:
    chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: 55.0.0
    helm:
      releaseName: prometheus
      values: |
        prometheus:
          prometheusSpec:
            retention: 7d
            storageSpec:
              volumeClaimTemplate:
                spec:
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 10Gi
        grafana:
          adminPassword: admin123

  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 8. Configure Sync Waves and Hooks

### 8.1 Sync Waves

Use annotations to control deployment order:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Deploy first
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Deploy second
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo-app
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy third
```

### 8.2 Sync Hooks

Create pre-sync and post-sync jobs:

```yaml
# Pre-sync hook - database migration
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: demo-app
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: migrate/migrate
          command: ["migrate", "-path", "/migrations", "-database", "postgres://...", "up"]
      restartPolicy: Never
---
# Post-sync hook - smoke test
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  namespace: demo-app
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: test
          image: curlimages/curl
          command: ["curl", "-f", "http://demo-app:8080/health"]
      restartPolicy: Never
```

---

## 9. Configure Notifications

### 9.1 Install ArgoCD Notifications

Already installed with ArgoCD. Configure notifications:

Create `argocd/argocd-notifications-cm.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Notification services
  service.slack: |
    token: $slack-token

  # Notification templates
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} is now running new version.
    slack:
      attachments: |
        [{
          "title": "{{ .app.metadata.name}}",
          "title_link":"{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "#18be52",
          "fields": [
          {
            "title": "Sync Status",
            "value": "{{.app.status.sync.status}}",
            "short": true
          },
          {
            "title": "Repository",
            "value": "{{.app.spec.source.repoURL}}",
            "short": true
          }
          ]
        }]

  template.app-health-degraded: |
    message: |
      Application {{.app.metadata.name}} has degraded health.
    slack:
      attachments: |
        [{
          "title": "{{ .app.metadata.name}}",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "#f4c030",
          "fields": [
          {
            "title": "Health Status",
            "value": "{{.app.status.health.status}}",
            "short": true
          }
          ]
        }]

  template.app-sync-failed: |
    message: |
      Application {{.app.metadata.name}} sync failed.
    slack:
      attachments: |
        [{
          "title": "{{ .app.metadata.name}}",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "#E96D76",
          "fields": [
          {
            "title": "Sync Status",
            "value": "{{.app.status.sync.status}}",
            "short": true
          }
          ]
        }]

  # Triggers
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]

  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]
```

Create secret for Slack token:

```bash
kubectl create secret generic argocd-notifications-secret \
  --from-literal=slack-token=xoxb-your-slack-token \
  -n argocd
```

### 9.2 Subscribe Application to Notifications

Add annotations to application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.slack: channel-name
    notifications.argoproj.io/subscribe.on-health-degraded.slack: channel-name
    notifications.argoproj.io/subscribe.on-sync-failed.slack: channel-name
```

---

## 10. Configure ApplicationSet

### 10.1 Create ApplicationSet for Multiple Environments

Create `argocd/applicationset.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: demo-app-environments
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - environment: dev
            namespace: demo-app-dev
            replicas: "1"
          - environment: staging
            namespace: demo-app-staging
            replicas: "2"
          - environment: prod
            namespace: demo-app-prod
            replicas: "3"

  template:
    metadata:
      name: 'demo-app-{{environment}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-username/your-repo.git
        targetRevision: main
        path: k8s/overlays/{{environment}}
        kustomize:
          commonLabels:
            environment: '{{environment}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

Apply:

```bash
kubectl apply -f argocd/applicationset.yaml

# Verify - should create 3 applications
argocd app list
```

---

## 11. Configure High Availability (Optional)

### 11.1 Scale ArgoCD Components

```bash
# Scale repo server
kubectl scale deployment argocd-repo-server -n argocd --replicas=2

# Scale application controller
kubectl scale statefulset argocd-application-controller -n argocd --replicas=2

# Scale server
kubectl scale deployment argocd-server -n argocd --replicas=2
```

### 11.2 Configure Redis HA

For production, use Redis HA:

```bash
# Install Redis HA using Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis-ha bitnami/redis \
  --namespace argocd \
  --set architecture=replication \
  --set auth.enabled=false
```

---

## 12. Monitoring and Metrics

### 12.1 Enable Prometheus Metrics

Metrics are already exposed. Create ServiceMonitor:

Create `argocd/servicemonitor.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  namespaceSelector:
    matchNames:
      - argocd
  endpoints:
    - port: metrics
      interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  namespaceSelector:
    matchNames:
      - argocd
  endpoints:
    - port: metrics
      interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  namespaceSelector:
    matchNames:
      - argocd
  endpoints:
    - port: metrics
      interval: 30s
```

Apply:

```bash
kubectl apply -f argocd/servicemonitor.yaml
```

### 12.2 Import Grafana Dashboard

ArgoCD provides official Grafana dashboards:

- Dashboard ID: 14584 (ArgoCD Operational)
- Dashboard ID: 14585 (ArgoCD Application)

---

## 13. Security Best Practices

### 13.1 Disable Admin User (Production)

```bash
# Create additional users first, then disable admin
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"admin.enabled":"false"}}'
```

### 13.2 Enable TLS for Repository Connections

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: repo-tls-cert
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: https://github.com/your-org
  tlsClientCertData: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  tlsClientCertKey: |
    -----BEGIN RSA PRIVATE KEY----- //pragma: allowlist secret
    ...
    -----END RSA PRIVATE KEY-----
```

### 13.3 Configure Network Policies

Create `argocd/networkpolicy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-server
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 8083
  egress:
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 6379
```

---

## 14. Backup and Disaster Recovery

### 14.1 Backup ArgoCD Configuration

```bash
# Export all applications
argocd app list -o yaml > argocd-apps-backup.yaml

# Export all projects
argocd proj list -o yaml > argocd-projects-backup.yaml

# Backup ArgoCD namespace
kubectl get all,cm,secret -n argocd -o yaml > argocd-namespace-backup.yaml
```

### 14.2 Automated Backup Script

Create `scripts/backup-argocd.sh`:

```bash
#!/bin/bash
set -e

BACKUP_DIR="./backups/argocd-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔄 Backing up ArgoCD configuration..."

# Export applications
argocd app list -o yaml > "$BACKUP_DIR/applications.yaml"

# Export projects
argocd proj list -o yaml > "$BACKUP_DIR/projects.yaml"

# Export repositories
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository -o yaml > "$BACKUP_DIR/repositories.yaml"

# Export ConfigMaps
kubectl get cm -n argocd -o yaml > "$BACKUP_DIR/configmaps.yaml"

# Export RBAC
kubectl get cm argocd-rbac-cm -n argocd -o yaml > "$BACKUP_DIR/rbac.yaml"

echo "✅ Backup completed: $BACKUP_DIR"
```

---

## 15. Troubleshooting

### Issue 1: Application Out of Sync

```bash
# Check application status
argocd app get demo-app

# View differences
argocd app diff demo-app

# Force sync
argocd app sync demo-app --force

# Refresh application
argocd app refresh demo-app
```

### Issue 2: Repository Connection Failed

```bash
# Test repository connection
argocd repo get https://github.com/your-username/your-repo.git

# Check repository credentials
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository

# View repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -f
```

### Issue 3: Sync Fails with Permission Error

```bash
# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Verify RBAC permissions
kubectl auth can-i create deployments --namespace demo-app --as system:serviceaccount:argocd:argocd-application-controller
```

### Issue 4: High Memory Usage

```bash
# Check resource usage
kubectl top pods -n argocd

# Increase memory limits
kubectl set resources deployment argocd-repo-server -n argocd --limits=memory=2Gi

# Or edit deployment
kubectl edit deployment argocd-repo-server -n argocd
```

---

## 16. Useful Commands

```bash
# List all applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# Delete application
argocd app delete <app-name>

# View application logs
argocd app logs <app-name>

# View application history
argocd app history <app-name>

# Rollback application
argocd app rollback <app-name> <revision>

# List repositories
argocd repo list

# List projects
argocd proj list

# View cluster info
argocd cluster list

# Get ArgoCD version
argocd version
```

---

## 17. Automation Script

Create `scripts/install-argocd.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Installing ArgoCD on Kubernetes..."

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get initial admin password
echo ""
echo "✅ ArgoCD installed successfully!"
echo ""
echo "Initial Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Access ArgoCD:"
echo "  Port Forward: kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "  URL: https://localhost:8443"
echo "  Username: admin"
echo ""
echo "Install ArgoCD CLI:"
echo "  brew install argocd"
```

Make it executable:

```bash
chmod +x scripts/install-argocd.sh
```

---

## 18. Verification Checklist

Before proceeding to the next section, verify:

- [ ] ArgoCD pods are running
- [ ] ArgoCD is accessible via port-forward or ingress
- [ ] Admin login works
- [ ] ArgoCD CLI is installed and working
- [ ] Git repository is added
- [ ] Projects are created
- [ ] Test application is deployed and synced
- [ ] Notifications are configured (optional)
- [ ] Monitoring is enabled

### Verification Script

```bash
#!/bin/bash

echo "=== ArgoCD Verification ==="

echo -e "\n1. Pod Status:"
kubectl get pods -n argocd

echo -e "\n2. Service Status:"
kubectl get svc -n argocd

echo -e "\n3. Applications:"
argocd app list 2>/dev/null || echo "ArgoCD CLI not logged in"

echo -e "\n4. Projects:"
argocd proj list 2>/dev/null || echo "ArgoCD CLI not logged in"

echo -e "\n5. Repositories:"
argocd repo list 2>/dev/null || echo "ArgoCD CLI not logged in"

echo -e "\n6. Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo -e "\n✅ Verification complete!"
```

---

## Next Steps

Now that ArgoCD is set up, proceed to:

- **[04-monitoring-setup.md](./04-monitoring-setup.md)** - Install Prometheus and Grafana for monitoring

---

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://www.gitops.tech/)
- [ArgoCD Operator Manual](https://argo-cd.readthedocs.io/en/stable/operator-manual/)
- [ArgoCD Examples](https://github.com/argoproj/argocd-example-apps)
