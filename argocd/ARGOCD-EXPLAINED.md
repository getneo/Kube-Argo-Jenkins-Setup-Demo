# ArgoCD Application Manifests - Detailed Explanation

This document explains the ArgoCD Application manifests created for the demo application across different environments.

## Table of Contents
1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Application Manifest Breakdown](#application-manifest-breakdown)
4. [Environment-Specific Configurations](#environment-specific-configurations)
5. [Sync Policies Explained](#sync-policies-explained)
6. [Best Practices](#best-practices)

---

## Overview

### What is an ArgoCD Application?

An ArgoCD Application is a Custom Resource Definition (CRD) that tells ArgoCD:
- **WHERE** to get the application manifests (Git repository)
- **WHAT** to deploy (Helm chart, Kustomize, or raw manifests)
- **WHERE** to deploy it (Kubernetes cluster and namespace)
- **HOW** to sync it (automatic or manual, with what policies)

### Why Three Applications?

We created three separate applications for different environments:
1. **demo-app-dev**: Development environment (fast iteration, auto-sync)
2. **demo-app-staging**: Staging environment (testing, auto-sync)
3. **demo-app-prod**: Production environment (manual sync, more control)

---

## File Structure

```
argocd/
├── applications/
│   └── demo-app-dev.yaml          # Contains all 3 applications
│       ├── demo-app-dev           # Development
│       ├── demo-app-staging       # Staging
│       └── demo-app-prod          # Production
├── projects/
│   └── (future: custom projects)
└── ARGOCD-EXPLAINED.md            # This file
```

---

## Application Manifest Breakdown

Let's break down each section of the Application manifest:

### 1. Metadata Section

```yaml
metadata:
  name: demo-app-dev              # Application name in ArgoCD
  namespace: argocd               # ArgoCD's namespace (not the app's)
  labels:
    app: demo-app
    environment: development
    managed-by: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
```

**Explanation**:
- `name`: Unique identifier for this application in ArgoCD
- `namespace`: Always `argocd` (where ArgoCD is installed)
- `labels`: For organization and filtering in ArgoCD UI
- `finalizers`: Ensures proper cleanup when application is deleted

**Why finalizers?**
- Without finalizer: Deleting the Application leaves resources in Kubernetes
- With finalizer: ArgoCD deletes all deployed resources first, then the Application

### 2. Project Section

```yaml
spec:
  project: default
```

**Explanation**:
- `project`: ArgoCD project that groups applications
- `default`: Built-in project with no restrictions
- Custom projects can enforce:
  - Which Git repos can be used
  - Which clusters can be deployed to
  - Which namespaces are allowed
  - RBAC policies

**Example Custom Project**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: demo-apps
spec:
  sourceRepos:
    - 'https://github.com/your-org/*'
  destinations:
    - namespace: 'demo-app-*'
      server: 'https://kubernetes.default.svc'
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
```

### 3. Source Section

```yaml
source:
  repoURL: https://github.com/your-username/CKA.git
  targetRevision: main
  path: demo-app/helm-chart/demo-app

  helm:
    valueFiles:
      - values-dev.yaml

    parameters:
      - name: replicaCount
        value: "1"
      - name: image.tag
        value: "latest"

    releaseName: demo-app-dev
```

**Explanation**:

#### repoURL
- Git repository containing the application manifests
- Supports: GitHub, GitLab, Bitbucket, generic Git
- Can use HTTPS or SSH

#### targetRevision
- Branch, tag, or commit SHA to track
- Examples:
  - `main` - Track main branch
  - `v1.0.0` - Track specific tag
  - `abc123` - Track specific commit
  - `HEAD` - Track latest commit

#### path
- Directory in the repo containing manifests
- Can be:
  - Helm chart directory
  - Kustomize directory
  - Directory with raw YAML files

#### helm.valueFiles
- List of values files to use
- Order matters (later files override earlier ones)
- Examples:
  ```yaml
  valueFiles:
    - values.yaml          # Base values
    - values-dev.yaml      # Environment overrides
    - values-custom.yaml   # Custom overrides
  ```

#### helm.parameters
- Override specific Helm values
- Takes precedence over valueFiles
- Useful for:
  - Dynamic values (from CI/CD)
  - Environment-specific overrides
  - Quick testing

**Parameter Format**:
```yaml
parameters:
  - name: image.tag              # Dot notation for nested values
    value: "v1.2.3"
  - name: ingress.hosts[0].host  # Array notation
    value: "app.example.com"
```

#### helm.releaseName
- Helm release name
- Used in: `helm list`, resource names
- Should be unique per namespace

### 4. Destination Section

```yaml
destination:
  server: https://kubernetes.default.svc
  namespace: demo-app-dev
```

**Explanation**:

#### server
- Kubernetes API server URL
- `https://kubernetes.default.svc` = in-cluster (same cluster as ArgoCD)
- Can deploy to external clusters:
  ```yaml
  server: https://external-cluster.example.com
  ```

#### namespace
- Target namespace for deployment
- Will be created if `CreateNamespace=true` in syncOptions
- Must match namespace in manifests (or use namespace override)

### 5. Sync Policy Section

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
    allowEmpty: false

  syncOptions:
    - CreateNamespace=true
    - PruneLast=true
    - ApplyOutOfSyncOnly=true
    - ServerSideApply=true

  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

**Explanation**:

#### automated.prune
- **true**: Delete resources removed from Git
- **false**: Keep resources even if removed from Git

**Example**:
```
Git: deployment.yaml, service.yaml
Cluster: deployment, service, configmap

With prune=true:  configmap will be deleted
With prune=false: configmap will remain
```

#### automated.selfHeal
- **true**: Automatically revert manual changes
- **false**: Allow manual changes (show as OutOfSync)

**Example**:
```
Git: replicas: 2
Someone runs: kubectl scale deployment demo-app --replicas=5

With selfHeal=true:  ArgoCD reverts to 2 replicas
With selfHeal=false: Shows OutOfSync, waits for manual sync
```

#### automated.allowEmpty
- **true**: Allow syncing when no resources found
- **false**: Fail sync if no resources found

#### syncOptions

**CreateNamespace=true**
- Creates namespace if it doesn't exist
- Useful for new environments

**PruneLast=true**
- Deletes old resources AFTER new ones are healthy
- Prevents downtime during updates

**ApplyOutOfSyncOnly=true**
- Only applies resources that changed
- Faster syncs, less cluster load

**ServerSideApply=true**
- Uses Kubernetes server-side apply (1.22+)
- Better conflict resolution
- Tracks field ownership

**Other useful options**:
```yaml
syncOptions:
  - Validate=false              # Skip validation
  - SkipDryRunOnMissingResource=true
  - RespectIgnoreDifferences=true
  - Replace=true                # Use replace instead of apply
```

#### retry
- Automatic retry on sync failure
- Exponential backoff prevents overwhelming cluster

**Example backoff**:
```
Attempt 1: Wait 5s
Attempt 2: Wait 10s (5s × 2)
Attempt 3: Wait 20s (10s × 2)
Attempt 4: Wait 40s (20s × 2)
Attempt 5: Wait 80s (40s × 2, capped at 3m = 180s)
```

### 6. Ignore Differences Section

```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas

  - group: ""
    kind: Service
    jsonPointers:
      - /spec/clusterIP
```

**Explanation**:

Tells ArgoCD to ignore certain fields when comparing Git vs Cluster.

**Why ignore replicas?**
- HPA (HorizontalPodAutoscaler) manages replicas
- ArgoCD shouldn't fight with HPA
- Prevents constant OutOfSync status

**Why ignore clusterIP?**
- Kubernetes assigns clusterIP automatically
- Can't be changed after creation
- Not in Git manifests

**Other common ignores**:
```yaml
ignoreDifferences:
  # Ignore annotations added by other controllers
  - group: ""
    kind: Pod
    jsonPointers:
      - /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration

  # Ignore status fields
  - group: apps
    kind: Deployment
    jsonPointers:
      - /status

  # Ignore secrets managed by external-secrets
  - group: ""
    kind: Secret
    jqPathExpressions:
      - .data
```

### 7. Revision History Limit

```yaml
revisionHistoryLimit: 10
```

**Explanation**:
- Number of previous revisions to keep
- Used for rollback in ArgoCD UI
- Higher number = more rollback options, more storage

**Recommendations**:
- Development: 5-10 revisions
- Staging: 10-15 revisions
- Production: 20-30 revisions

---

## Environment-Specific Configurations

### Development Environment

```yaml
name: demo-app-dev
targetRevision: main
valueFiles: [values-dev.yaml]
parameters:
  - name: replicaCount
    value: "1"
  - name: image.tag
    value: "latest"
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Characteristics**:
- ✅ Auto-sync enabled (fast iteration)
- ✅ Self-heal enabled (auto-correct drift)
- ✅ Prune enabled (clean up old resources)
- ✅ Uses `latest` tag (always newest)
- ✅ Single replica (save resources)
- ✅ Tracks `main` branch (latest code)

**Use Case**: Rapid development and testing

### Staging Environment

```yaml
name: demo-app-staging
targetRevision: main
valueFiles: [values.yaml]
parameters:
  - name: replicaCount
    value: "2"
  - name: environment
    value: "staging"
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Characteristics**:
- ✅ Auto-sync enabled (test automation)
- ✅ Self-heal enabled
- ✅ Multiple replicas (test HA)
- ✅ Uses default values (closer to prod)
- ✅ Tracks `main` branch

**Use Case**: Pre-production testing and validation

### Production Environment

```yaml
name: demo-app-prod
targetRevision: main  # Or 'release' branch
valueFiles: [values-prod.yaml]
parameters:
  - name: replicaCount
    value: "3"
  - name: image.tag
    value: "1.0.0"  # Specific version
syncPolicy:
  automated:
    prune: false      # Manual deletion
    selfHeal: false   # Manual correction
revisionHistoryLimit: 20
```

**Characteristics**:
- ❌ Auto-sync disabled (manual control)
- ❌ Self-heal disabled (prevent auto-changes)
- ❌ Prune disabled (manual deletion)
- ✅ Specific image version (not `latest`)
- ✅ Multiple replicas (high availability)
- ✅ More revision history (rollback options)
- ✅ Production values file

**Use Case**: Production deployments with manual approval

---

## Sync Policies Explained

### Automatic vs Manual Sync

**Automatic Sync**:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Behavior**:
- ArgoCD syncs automatically when Git changes
- No human intervention needed
- Fast deployment (seconds to minutes)

**Best for**: Dev, Staging, Non-critical apps

**Manual Sync**:
```yaml
syncPolicy:
  automated:
    prune: false
    selfHeal: false
```

**Behavior**:
- ArgoCD detects changes but waits
- Human must click "Sync" button
- Allows review before deployment

**Best for**: Production, Critical apps, Compliance requirements

### Sync Strategies

**Strategy 1: Full Auto (Dev)**
```yaml
automated:
  prune: true
  selfHeal: true
```
- Fastest
- Least control
- Good for development

**Strategy 2: Semi-Auto (Staging)**
```yaml
automated:
  prune: true
  selfHeal: false
```
- Auto-deploy new changes
- Manual correction of drift
- Good for staging

**Strategy 3: Manual (Production)**
```yaml
automated:
  prune: false
  selfHeal: false
```
- Full control
- Manual approval
- Good for production

**Strategy 4: Auto with Approval**
```yaml
automated:
  prune: true
  selfHeal: true
syncWindows:
  - kind: allow
    schedule: "0 2 * * *"  # Only sync at 2 AM
    duration: 1h
```
- Auto-sync during maintenance window
- Prevents unexpected changes
- Good for production with maintenance windows

---

## Best Practices

### 1. Use Separate Applications per Environment

✅ **Good**:
```
demo-app-dev
demo-app-staging
demo-app-prod
```

❌ **Bad**:
```
demo-app (with manual environment switching)
```

**Why?**
- Clear separation
- Different sync policies
- Independent rollback
- Better visibility

### 2. Use Specific Tags in Production

✅ **Good**:
```yaml
image:
  tag: "v1.2.3"
```

❌ **Bad**:
```yaml
image:
  tag: "latest"
```

**Why?**
- Predictable deployments
- Easy rollback
- Audit trail
- No surprises

### 3. Disable Auto-Sync in Production

✅ **Good**:
```yaml
syncPolicy:
  automated:
    prune: false
    selfHeal: false
```

❌ **Bad**:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Why?**
- Manual approval
- Review changes
- Prevent accidents
- Compliance

### 4. Use Ignore Differences Wisely

✅ **Good**:
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas  # HPA manages this
```

❌ **Bad**:
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec  # Ignores everything!
```

**Why?**
- Specific ignores
- Still detect real drift
- Don't hide problems

### 5. Set Appropriate Revision History

✅ **Good**:
```yaml
# Development
revisionHistoryLimit: 5

# Staging
revisionHistoryLimit: 10

# Production
revisionHistoryLimit: 20
```

❌ **Bad**:
```yaml
# Same for all environments
revisionHistoryLimit: 100
```

**Why?**
- Balance storage vs rollback needs
- Production needs more history
- Dev doesn't need much

### 6. Use Health Checks

✅ **Good**:
```yaml
# In Deployment
livenessProbe:
  httpGet:
    path: /health/live
readinessProbe:
  httpGet:
    path: /health/ready
```

**Why?**
- ArgoCD waits for healthy pods
- Prevents marking sync as successful when pods are failing
- Better rollout detection

### 7. Use Sync Waves for Dependencies

✅ **Good**:
```yaml
# Database (sync wave 0)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"

# Application (sync wave 1)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

**Why?**
- Ensures correct order
- Database before application
- ConfigMaps before Deployments

### 8. Use Sync Windows for Production

✅ **Good**:
```yaml
syncWindows:
  - kind: allow
    schedule: "0 2 * * *"  # 2 AM daily
    duration: 2h
    applications:
      - demo-app-prod
```

**Why?**
- Controlled deployment times
- Maintenance windows
- Avoid business hours

---

## Summary

### Key Takeaways

1. **Three Applications**: Dev (auto), Staging (auto), Prod (manual)
2. **Sync Policies**: Control how ArgoCD deploys
3. **Ignore Differences**: Prevent false OutOfSync status
4. **Environment-Specific**: Different configs for different needs
5. **Best Practices**: Specific tags, manual prod, health checks

### Quick Reference

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| Auto-sync | ✅ | ✅ | ❌ |
| Self-heal | ✅ | ✅ | ❌ |
| Prune | ✅ | ✅ | ❌ |
| Image tag | latest | latest | v1.0.0 |
| Replicas | 1 | 2 | 3 |
| History | 5 | 10 | 20 |

### Next Steps

1. Customize the manifests with your Git repo URL
2. Apply to ArgoCD: `kubectl apply -f argocd/applications/`
3. Watch in ArgoCD UI: https://localhost:8081
4. Test the sync process
5. Practice rollback

Happy GitOps! 🚀
