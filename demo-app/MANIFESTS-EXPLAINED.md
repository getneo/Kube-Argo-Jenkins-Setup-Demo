# Kubernetes Manifests Explained

This document provides a detailed explanation of all Kubernetes manifests in the `deployments/kubernetes/` directory and shows how they work together to create a production-ready deployment.

## Table of Contents
1. [Overview](#overview)
2. [Manifest Files Breakdown](#manifest-files-breakdown)
3. [How They Work Together](#how-they-work-together)
4. [Best Practices Implemented](#best-practices-implemented)
5. [Converting to Helm Chart](#converting-to-helm-chart)

---

## Overview

The demo application uses **10 Kubernetes manifest files** that follow industry best practices for:
- **Security**: RBAC, SecurityContext, NetworkPolicies
- **Reliability**: Health checks, PodDisruptionBudget, Anti-affinity
- **Scalability**: HorizontalPodAutoscaler, Resource limits
- **Observability**: Prometheus metrics, ServiceMonitor
- **Configuration**: ConfigMaps, Environment variables

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Namespace: demo-app                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Ingress    │  │   Service    │  │ NetworkPolicy│     │
│  │ demo-app.local│ │  ClusterIP   │  │  (Security)  │     │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘     │
│         │                  │                                │
│         └──────────────────┼────────────────────┐          │
│                            │                    │          │
│                    ┌───────▼────────┐           │          │
│                    │   Deployment   │           │          │
│                    │   (2 replicas) │◄──────────┤          │
│                    └───────┬────────┘           │          │
│                            │                    │          │
│              ┌─────────────┼─────────────┐      │          │
│              │             │             │      │          │
│         ┌────▼────┐   ┌────▼────┐       │      │          │
│         │  Pod 1  │   │  Pod 2  │       │      │          │
│         └─────────┘   └─────────┘       │      │          │
│                                          │      │          │
│  ┌──────────────┐  ┌──────────────┐     │      │          │
│  │     HPA      │  │     PDB      │     │      │          │
│  │ (Autoscaler) │  │ (Disruption) │     │      │          │
│  └──────────────┘  └──────────────┘     │      │          │
│                                          │      │          │
│  ┌──────────────┐  ┌──────────────┐     │      │          │
│  │  ConfigMap   │  │ServiceAccount│     │      │          │
│  │   (Config)   │  │    (RBAC)    │◄────┘      │          │
│  └──────────────┘  └──────────────┘            │          │
│                                                 │          │
│  ┌──────────────────────────────────────────┐  │          │
│  │         ServiceMonitor                   │  │          │
│  │      (Prometheus Integration)            │◄─┘          │
│  └──────────────────────────────────────────┘             │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Manifest Files Breakdown

### 1. **00-namespace.yaml** - Namespace Definition

**Purpose**: Isolates resources and provides logical grouping.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
  labels:
    name: demo-app
    environment: development
    managed-by: argocd
```

**Key Points**:
- Creates isolated namespace for the application
- Labels help with organization and ArgoCD tracking
- Enables resource quotas and network policies per namespace

**Best Practices**:
✅ Use namespaces to separate environments (dev, staging, prod)  
✅ Add labels for management tools (ArgoCD, Helm)  
✅ Apply ResourceQuotas and LimitRanges at namespace level

---

### 2. **01-configmap.yaml** - Configuration Management

**Purpose**: Stores non-sensitive configuration data.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-app-config
  namespace: demo-app
data:
  APP_NAME: "demo-app"
  ENVIRONMENT: "development"
  LOG_LEVEL: "info"
  PORT: "8080"
```

**Key Points**:
- Decouples configuration from application code
- Can be updated without rebuilding container images
- Injected as environment variables via `envFrom`

**Best Practices**:
✅ Store only non-sensitive data (use Secrets for sensitive data)  
✅ Use meaningful key names  
✅ Version ConfigMaps for rollback capability  
✅ Consider using ConfigMap volumes for large configs

**When to Use**:
- Application settings (log levels, feature flags)
- Environment-specific configurations
- Non-sensitive API endpoints

---

### 3. **02-deployment.yaml** - Application Deployment (159 lines)

**Purpose**: Manages the application pods with desired state.

#### Key Sections:

##### A. Replica Management
```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Can have 3 pods during update
      maxUnavailable: 0  # Always maintain 2 pods minimum
```

**Why 2 replicas?**
- High availability (one pod can fail)
- Load distribution
- Zero-downtime deployments

##### B. Security Context (Pod Level)
```yaml
securityContext:
  runAsNonRoot: true      # Prevents root execution
  runAsUser: 65534        # Nobody user (least privilege)
  fsGroup: 65534          # File system group
  seccompProfile:
    type: RuntimeDefault  # Restricts syscalls
```

##### C. Security Context (Container Level)
```yaml
securityContext:
  allowPrivilegeEscalation: false  # Prevents privilege escalation
  readOnlyRootFilesystem: true     # Immutable filesystem
  runAsNonRoot: true
  runAsUser: 65534
  capabilities:
    drop: [ALL]                    # Drops all Linux capabilities
```

**Security Layers**:
1. Non-root user (UID 65534)
2. Read-only filesystem
3. No privilege escalation
4. Dropped capabilities
5. Seccomp profile

##### D. Resource Management
```yaml
resources:
  requests:
    cpu: 100m      # Guaranteed CPU
    memory: 128Mi  # Guaranteed memory
  limits:
    cpu: 500m      # Maximum CPU
    memory: 256Mi  # Maximum memory
```

**Why These Values?**
- **Requests**: Minimum needed for scheduling
- **Limits**: Prevents resource hogging
- **Ratio**: 5x CPU, 2x memory headroom

##### E. Health Checks
```yaml
# Liveness Probe - Is the app alive?
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3    # Restart after 3 failures

# Readiness Probe - Can it serve traffic?
readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3    # Remove from service after 3 failures

# Startup Probe - For slow-starting apps
startupProbe:
  httpGet:
    path: /health/live
    port: http
  failureThreshold: 12   # 60 seconds max startup time
  periodSeconds: 5
```

**Probe Strategy**:
- **Startup**: Gives app time to initialize (60s max)
- **Liveness**: Restarts unhealthy pods
- **Readiness**: Removes pods from load balancer

##### F. Environment Variables
```yaml
envFrom:
- configMapRef:
    name: demo-app-config  # Loads all ConfigMap keys

env:
- name: APP_VERSION
  value: "1.0.0"
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name  # Downward API
```

**Downward API Benefits**:
- Pods know their own name, namespace, IP
- Useful for logging and debugging
- No external API calls needed

##### G. Volume Mounts
```yaml
volumeMounts:
- name: tmp
  mountPath: /tmp        # Writable temp directory
- name: cache
  mountPath: /.cache     # Writable cache directory

volumes:
- name: tmp
  emptyDir: {}           # Ephemeral storage
- name: cache
  emptyDir: {}
```

**Why EmptyDir?**
- Read-only filesystem needs writable directories
- Temporary data doesn't need persistence
- Cleaned up when pod terminates

##### H. Pod Anti-Affinity
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - demo-app
        topologyKey: kubernetes.io/hostname
```

**Purpose**: Spreads pods across different nodes for high availability.

**Best Practices**:
✅ Use `preferred` (soft) for flexibility  
✅ Use `required` (hard) for strict separation  
✅ Consider zone anti-affinity for multi-AZ deployments

---

### 4. **03-service.yaml** - Service Discovery

**Purpose**: Provides stable network endpoint for pods.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  annotations:
    prometheus.io/scrape: "true"  # Prometheus discovery
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  type: ClusterIP      # Internal only
  selector:
    app: demo-app      # Selects pods with this label
  ports:
  - name: http
    port: 80           # Service port
    targetPort: http   # Pod port (8080)
```

**Service Types**:
- **ClusterIP**: Internal only (our choice)
- **NodePort**: Exposes on node IP
- **LoadBalancer**: Cloud load balancer
- **ExternalName**: DNS CNAME

**Why ClusterIP?**
- Internal communication only
- Ingress handles external access
- More secure (not exposed to internet)

---

### 5. **04-serviceaccount.yaml** - RBAC Configuration

**Purpose**: Implements least-privilege access control.

#### Components:

##### A. ServiceAccount
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-app
automountServiceAccountToken: true
```

##### B. Role (Namespace-scoped permissions)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]  # Read-only
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]                   # Read-only
```

##### C. RoleBinding (Links ServiceAccount to Role)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
roleRef:
  kind: Role
  name: demo-app
subjects:
- kind: ServiceAccount
  name: demo-app
```

**RBAC Hierarchy**:
```
ServiceAccount → RoleBinding → Role → Permissions
```

**Best Practices**:
✅ Use ServiceAccounts (not default)  
✅ Grant minimum required permissions  
✅ Use Role (namespace) over ClusterRole when possible  
✅ Regularly audit permissions

---

### 6. **05-ingress.yaml** - External Access

**Purpose**: Routes external HTTP(S) traffic to the service.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: demo-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-app
            port:
              number: 80
```

**Traffic Flow**:
```
Internet → Ingress Controller → Ingress → Service → Pods
```

**Ingress Features**:
- Host-based routing (demo-app.local)
- Path-based routing (/, /api/*)
- SSL/TLS termination
- URL rewriting
- Rate limiting (via annotations)

**Production Considerations**:
- Use real domain names
- Enable SSL/TLS with cert-manager
- Add rate limiting
- Configure CORS policies

---

### 7. **06-networkpolicy.yaml** - Network Security

**Purpose**: Controls network traffic at the pod level (firewall rules).

#### Ingress Rules (Incoming Traffic)

##### Allow from Ingress Controller
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        app.kubernetes.io/name: ingress-nginx
  ports:
  - protocol: TCP
    port: 8080
```

##### Allow from Prometheus
```yaml
- from:
  - namespaceSelector:
      matchLabels:
        name: monitoring
    podSelector:
      matchLabels:
        app.kubernetes.io/name: prometheus
  ports:
  - protocol: TCP
    port: 8080
```

#### Egress Rules (Outgoing Traffic)

##### Allow DNS Resolution
```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
```

##### Allow HTTPS to External Services
```yaml
- to:
  - namespaceSelector: {}
  ports:
  - protocol: TCP
    port: 443
```

**Network Policy Strategy**:
```
Default: Deny All
↓
Explicitly Allow:
  - Ingress from Ingress Controller
  - Ingress from Prometheus
  - Egress to DNS
  - Egress to HTTPS
```

**Best Practices**:
✅ Start with deny-all, then allow specific traffic  
✅ Use namespace and pod selectors  
✅ Document why each rule exists  
✅ Test policies in staging first

---

### 8. **07-servicemonitor.yaml** - Prometheus Integration

**Purpose**: Configures Prometheus to scrape metrics from the application.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: demo-app
  labels:
    release: prometheus  # Prometheus operator selector
spec:
  selector:
    matchLabels:
      app: demo-app
  endpoints:
  - port: http
    path: /metrics
    interval: 30s        # Scrape every 30 seconds
    scrapeTimeout: 10s
```

**How It Works**:
1. Prometheus Operator watches for ServiceMonitors
2. ServiceMonitor selects services with `app: demo-app`
3. Prometheus scrapes `/metrics` endpoint every 30s
4. Metrics stored in Prometheus TSDB

**Metrics Exposed**:
- Go runtime metrics (goroutines, memory, GC)
- HTTP request metrics (count, duration, errors)
- Custom application metrics

---

### 9. **08-hpa.yaml** - Horizontal Pod Autoscaler

**Purpose**: Automatically scales pods based on resource utilization.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    kind: Deployment
    name: demo-app
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale at 70% CPU
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80  # Scale at 80% memory
```

**Scaling Behavior**:
```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
    policies:
    - type: Percent
      value: 50                      # Remove max 50% of pods
      periodSeconds: 60
  scaleUp:
    stabilizationWindowSeconds: 0    # Scale up immediately
    policies:
    - type: Percent
      value: 100                     # Double pods
      periodSeconds: 30
    - type: Pods
      value: 2                       # Or add 2 pods
      periodSeconds: 30
    selectPolicy: Max                # Use whichever is larger
```

**Scaling Strategy**:
- **Scale Up**: Fast (immediate, aggressive)
- **Scale Down**: Slow (5 min wait, conservative)
- **Prevents**: Flapping (rapid scale up/down)

**HPA Algorithm**:
```
desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]
```

**Example**:
- Current: 2 replicas, 85% CPU
- Target: 70% CPU
- Desired: ceil[2 * (85/70)] = ceil[2.43] = 3 replicas

---

### 10. **09-pdb.yaml** - Pod Disruption Budget

**Purpose**: Ensures minimum availability during voluntary disruptions.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: demo-app
spec:
  minAvailable: 1      # Always keep at least 1 pod running
  selector:
    matchLabels:
      app: demo-app
```

**Voluntary Disruptions**:
- Node drains (maintenance)
- Cluster upgrades
- Pod evictions
- Manual deletions

**PDB Strategies**:
```yaml
# Option 1: Minimum available
minAvailable: 1

# Option 2: Maximum unavailable
maxUnavailable: 1

# Option 3: Percentage
minAvailable: 50%
```

**Why PDB Matters**:
- Prevents all pods from being evicted at once
- Ensures service availability during maintenance
- Works with node drains and cluster autoscaler

**Best Practices**:
✅ Set `minAvailable` to at least 1 for HA  
✅ Use with multiple replicas  
✅ Consider `maxUnavailable` for large deployments  
✅ Test with `kubectl drain` commands

---

## How They Work Together

### Deployment Flow

```
1. Namespace Created
   └─> Isolated environment for all resources

2. ConfigMap Created
   └─> Configuration data ready for injection

3. ServiceAccount + RBAC Created
   └─> Identity and permissions established

4. Deployment Created
   ├─> Reads ConfigMap for environment variables
   ├─> Uses ServiceAccount for API access
   ├─> Creates 2 pods with security contexts
   ├─> Mounts emptyDir volumes
   └─> Configures health probes

5. Service Created
   └─> Provides stable endpoint for pods

6. Ingress Created
   └─> Routes external traffic to Service

7. NetworkPolicy Created
   └─> Restricts traffic to/from pods

8. ServiceMonitor Created
   └─> Prometheus starts scraping metrics

9. HPA Created
   └─> Monitors metrics and scales pods

10. PDB Created
    └─> Protects availability during disruptions
```

### Runtime Interactions

```
External Request Flow:
User → Ingress → Service → Pod (via NetworkPolicy)

Monitoring Flow:
Prometheus → ServiceMonitor → Service → Pod /metrics

Scaling Flow:
Metrics Server → HPA → Deployment → Pods

Configuration Flow:
ConfigMap → Deployment → Pod Environment Variables

Security Flow:
ServiceAccount → RBAC → Kubernetes API
```

---

## Best Practices Implemented

### 1. **Security** ✅
- Non-root user (UID 65534)
- Read-only root filesystem
- Dropped capabilities
- NetworkPolicies (deny-by-default)
- RBAC with least privilege
- Seccomp profile

### 2. **Reliability** ✅
- Multiple replicas (2)
- Health checks (liveness, readiness, startup)
- PodDisruptionBudget
- Graceful shutdown (30s)
- Pod anti-affinity
- Rolling updates (zero downtime)

### 3. **Scalability** ✅
- HorizontalPodAutoscaler
- Resource requests and limits
- Efficient resource utilization
- Load balancing via Service

### 4. **Observability** ✅
- Prometheus metrics
- ServiceMonitor
- Structured logging
- Request ID tracking
- Health endpoints

### 5. **Configuration Management** ✅
- ConfigMaps for non-sensitive data
- Environment variables
- Downward API for pod metadata
- Separation of config from code

### 6. **High Availability** ✅
- Multiple replicas
- Pod anti-affinity
- PodDisruptionBudget
- Health checks
- Zero-downtime deployments

---

## Converting to Helm Chart

Helm is a package manager for Kubernetes that uses templates to generate manifests dynamically.

### Why Convert to Helm?

**Benefits**:
1. **Parameterization**: Single chart, multiple environments
2. **Versioning**: Track chart versions
3. **Reusability**: Share charts across teams
4. **Templating**: DRY (Don't Repeat Yourself)
5. **Dependency Management**: Manage chart dependencies
6. **Rollback**: Easy rollback to previous versions

### Helm Chart Structure

```
demo-app-chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── values-dev.yaml         # Development overrides
├── values-staging.yaml     # Staging overrides
├── values-prod.yaml        # Production overrides
├── templates/
│   ├── NOTES.txt          # Post-install notes
│   ├── _helpers.tpl       # Template helpers
│   ├── namespace.yaml     # From 00-namespace.yaml
│   ├── configmap.yaml     # From 01-configmap.yaml
│   ├── deployment.yaml    # From 02-deployment.yaml
│   ├── service.yaml       # From 03-service.yaml
│   ├── serviceaccount.yaml # From 04-serviceaccount.yaml
│   ├── ingress.yaml       # From 05-ingress.yaml
│   ├── networkpolicy.yaml # From 06-networkpolicy.yaml
│   ├── servicemonitor.yaml # From 07-servicemonitor.yaml
│   ├── hpa.yaml           # From 08-hpa.yaml
│   └── pdb.yaml           # From 09-pdb.yaml
└── .helmignore            # Files to ignore
```

### Conversion Process

#### Step 1: Create Chart Structure
```bash
helm create demo-app-chart
rm -rf demo-app-chart/templates/*  # Remove default templates
```

#### Step 2: Define Chart.yaml
```yaml
apiVersion: v2
name: demo-app
description: A production-ready demo application
type: application
version: 1.0.0
appVersion: "1.0.0"
```

#### Step 3: Create values.yaml (Parameterize Everything)
```yaml
# Application
app:
  name: demo-app
  version: 1.0.0

# Image
image:
  repository: demo-app
  tag: latest
  pullPolicy: IfNotPresent

# Replicas
replicaCount: 2

# Resources
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

# Environment
environment: development
logLevel: info

# Ingress
ingress:
  enabled: true
  className: nginx
  host: demo-app.local
  tls:
    enabled: false

# Autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilization: 70
  targetMemoryUtilization: 80

# Monitoring
monitoring:
  enabled: true
  interval: 30s

# Security
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  fsGroup: 65534

# Network Policy
networkPolicy:
  enabled: true
```

#### Step 4: Convert Manifests to Templates

**Example: deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "demo-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "demo-app.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

#### Step 5: Create Helper Templates (_helpers.tpl)
```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "demo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "demo-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "demo-app.labels" -}}
helm.sh/chart: {{ include "demo-app.chart" . }}
{{ include "demo-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

### Using the Helm Chart

#### Install
```bash
# Development
helm install demo-app ./demo-app-chart \
  --namespace demo-app \
  --create-namespace \
  --values ./demo-app-chart/values-dev.yaml

# Production
helm install demo-app ./demo-app-chart \
  --namespace demo-app-prod \
  --create-namespace \
  --values ./demo-app-chart/values-prod.yaml
```

#### Upgrade
```bash
helm upgrade demo-app ./demo-app-chart \
  --namespace demo-app \
  --values ./demo-app-chart/values-dev.yaml
```

#### Rollback
```bash
helm rollback demo-app 1 --namespace demo-app
```

#### Uninstall
```bash
helm uninstall demo-app --namespace demo-app
```

### Environment-Specific Values

**values-dev.yaml**:
```yaml
environment: development
replicaCount: 1
ingress:
  host: demo-app-dev.local
resources:
  requests:
    cpu: 50m
    memory: 64Mi
```

**values-prod.yaml**:
```yaml
environment: production
replicaCount: 3
ingress:
  host: demo-app.example.com
  tls:
    enabled: true
resources:
  requests:
    cpu: 200m
    memory: 256Mi
autoscaling:
  maxReplicas: 10
```

---

## Next Steps

1. **Create Helm Chart**: Convert manifests to Helm templates
2. **Test Locally**: Deploy with different values files
3. **CI/CD Integration**: Use Helm in Jenkins/ArgoCD
4. **Chart Repository**: Publish to Helm repository
5. **Documentation**: Add NOTES.txt for post-install instructions

---

## Summary

The 10 Kubernetes manifests work together to create a:
- **Secure**: RBAC, SecurityContext, NetworkPolicies
- **Reliable**: Health checks, PDB, anti-affinity
- **Scalable**: HPA, resource limits
- **Observable**: Prometheus metrics, logging
- **Production-ready**: Following SRE best practices

Converting to Helm provides:
- **Flexibility**: Multiple environments from one chart
- **Maintainability**: DRY templates
- **Versioning**: Track changes over time
- **Reusability**: Share across teams

Ready to create the Helm chart? Let me know!
