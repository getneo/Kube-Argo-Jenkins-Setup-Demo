# Prometheus Stack Values File Explanation

## Overview

This document explains the `monitoring/prometheus-values.yaml` configuration file used to deploy the Prometheus monitoring stack on Kubernetes. The configuration is optimized for local Minikube development while following production best practices.

---

## File Structure

The values file configures multiple components:
1. **Prometheus Operator** - Manages Prometheus instances
2. **Prometheus Server** - Metrics collection and storage
3. **Alertmanager** - Alert routing and notifications
4. **Grafana** - Metrics visualization
5. **Exporters** - Node Exporter, Kube State Metrics
6. **Default Rules** - Pre-configured alerting rules

---

## Section-by-Section Explanation

### 1. Global Settings

```yaml
global:
  rbac:
    create: true
```

**Purpose:** Enable Role-Based Access Control (RBAC) for all components.

**Why:** RBAC ensures that each component has only the permissions it needs, following the principle of least privilege. This is a security best practice.

**What it does:**
- Creates ServiceAccounts for each component
- Creates Roles and RoleBindings with minimal permissions
- Prevents unauthorized access to cluster resources

---

### 2. Prometheus Operator

```yaml
prometheusOperator:
  enabled: true

  resources:
    limits:
      cpu: 200m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

**Purpose:** The Prometheus Operator automates the deployment and management of Prometheus instances.

**Resource Limits Explained:**
- **requests**: Guaranteed resources (Kubernetes will reserve these)
  - `cpu: 100m` = 0.1 CPU cores (10% of one core)
  - `memory: 256Mi` = 256 megabytes
- **limits**: Maximum resources the pod can use
  - `cpu: 200m` = 0.2 CPU cores (20% of one core)
  - `memory: 512Mi` = 512 megabytes

**Why these values:**
- Operator is lightweight, doesn't need much resources
- Suitable for Minikube with limited resources
- Prevents resource starvation of other components

```yaml
  admissionWebhooks:
    enabled: true
    patch:
      enabled: true
```

**Purpose:** Validates Prometheus custom resources before they're created.

**What it does:**
- Checks if ServiceMonitor, PrometheusRule configs are valid
- Prevents misconfigured resources from being deployed
- Auto-patches webhook certificates

---

### 3. Prometheus Server

```yaml
prometheus:
  enabled: true

  prometheusSpec:
    retention: 7d
    retentionSize: "5GB"
```

**Retention Settings:**
- **retention: 7d** - Keep metrics for 7 days
- **retentionSize: "5GB"** - Delete oldest data when storage exceeds 5GB

**Why 7 days:**
- Sufficient for local development and testing
- Balances storage usage with historical data needs
- Production typically uses 15-30 days

```yaml
    resources:
      requests:
        cpu: 250m
        memory: 1Gi
      limits:
        cpu: 1000m
        memory: 2Gi
```

**Resource Allocation:**
- **requests**: 250m CPU (25% of core), 1GB RAM
- **limits**: 1 CPU core, 2GB RAM

**Why these values:**
- Prometheus is memory-intensive (stores time-series data in RAM)
- 1GB is minimum for small clusters
- 2GB limit prevents OOM (Out of Memory) kills
- Reduced from production values for Minikube

```yaml
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
```

**Storage Configuration:**
- **storageClassName: standard** - Uses Minikube's default storage class
- **accessModes: ReadWriteOnce** - Volume can be mounted by one node only
- **storage: 10Gi** - 10 gigabytes of persistent storage

**Why persistent storage:**
- Metrics survive pod restarts
- Historical data preserved
- Essential for trend analysis

```yaml
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
```

**Service Monitor Selectors:**
- **Empty `{}`** = Monitor ALL ServiceMonitors in ALL namespaces

**What are ServiceMonitors:**
- Custom resources that tell Prometheus what to scrape
- Define which services expose metrics
- Automatically configure Prometheus scrape configs

**Why empty selectors:**
- Simplifies configuration for development
- Automatically discovers new services
- Production would use labels to filter specific monitors

```yaml
    scrapeInterval: 30s
    evaluationInterval: 30s
```

**Intervals:**
- **scrapeInterval: 30s** - Collect metrics every 30 seconds
- **evaluationInterval: 30s** - Evaluate alerting rules every 30 seconds

**Why 30 seconds:**
- Good balance between data granularity and resource usage
- More frequent = more data points but higher CPU/storage
- Less frequent = less accurate but lower resource usage
- Production often uses 15s for critical systems

```yaml
    externalLabels:
      cluster: minikube-local
      environment: development
```

**External Labels:**
- Added to ALL metrics from this Prometheus instance
- Useful when aggregating metrics from multiple clusters
- Helps identify the source of metrics

**Use cases:**
- Multi-cluster monitoring
- Federated Prometheus setups
- Long-term storage systems (Thanos, Cortex)

```yaml
    replicas: 1
```

**Replicas:**
- **1** = Single Prometheus instance (no HA)

**Why 1 for Minikube:**
- High Availability (HA) requires 2+ replicas
- HA doubles resource usage
- Not needed for local development
- Production should use 2-3 replicas

```yaml
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 2000
```

**Security Context:**
- **runAsNonRoot: true** - Prevents running as root user
- **runAsUser: 1000** - Runs as user ID 1000
- **fsGroup: 2000** - File system group ID

**Why this matters:**
- Security best practice (principle of least privilege)
- Prevents privilege escalation attacks
- Limits damage if container is compromised
- Required by many security policies (PodSecurityPolicies)

```yaml
    enableAdminAPI: false
```

**Admin API:**
- Disabled for security
- Admin API allows deleting data, shutting down Prometheus
- Only enable if you need programmatic management

---

### 4. Alertmanager

```yaml
alertmanager:
  enabled: true

  alertmanagerSpec:
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 100m
        memory: 256Mi
```

**Purpose:** Routes and manages alerts from Prometheus.

**Resource Allocation:**
- Very lightweight component
- Only processes alerts (not metrics)
- 50m CPU and 128Mi RAM is sufficient

**What Alertmanager does:**
- Receives alerts from Prometheus
- Groups similar alerts together
- Routes alerts to correct receivers (Slack, email, PagerDuty)
- Handles alert silencing and inhibition

```yaml
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
```

**Storage:**
- 2GB persistent storage for alert state
- Stores silences, notification history
- Much smaller than Prometheus (only stores alert metadata)

---

### 5. Grafana

```yaml
grafana:
  enabled: true

  adminPassword: admin123
```

**Admin Credentials:**
- **Username:** admin (default)
- **Password:** admin123

**⚠️ Security Note:**
- Change this password in production!
- Use Kubernetes secrets for sensitive data
- Consider using OAuth/SSO for authentication

```yaml
  resources:
    limits:
      cpu: 200m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

**Resource Allocation:**
- Grafana is relatively lightweight
- Most work is done by browser (client-side rendering)
- 256Mi RAM sufficient for small deployments

```yaml
  persistence:
    enabled: true
    storageClassName: standard
    size: 5Gi
```

**Persistence:**
- Stores dashboards, users, settings
- Survives pod restarts
- 5GB is plenty for dashboard storage

```yaml
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus.monitoring:9090
        access: proxy
        isDefault: true
```

**Datasource Configuration:**
- **name: Prometheus** - Display name in Grafana
- **type: prometheus** - Datasource type
- **url:** Internal Kubernetes service URL
  - Format: `http://<service-name>.<namespace>:<port>`
  - `prometheus-kube-prometheus-prometheus` = Helm release name + chart name
  - `monitoring` = namespace
  - `9090` = Prometheus default port
- **access: proxy** - Grafana proxies requests (more secure)
- **isDefault: true** - Used by default for new dashboards

**Why proxy access:**
- Browser doesn't need direct access to Prometheus
- Grafana handles authentication
- Works with network policies

```yaml
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
```

**Pre-installed Dashboards:**
- **gnetId: 7249** - Dashboard ID from grafana.com
- Automatically downloads and imports dashboard
- Three dashboards included:
  1. **7249** - Kubernetes Cluster overview
  2. **6417** - Kubernetes Pods monitoring
  3. **1860** - Node Exporter (server metrics)

**Why these dashboards:**
- Community-maintained and well-tested
- Cover most common monitoring needs
- Good starting point for customization

```yaml
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.local
```

**Ingress Configuration:**
- Exposes Grafana via `grafana.local` hostname
- Uses NGINX ingress controller
- Allows browser access without port-forward

**Access methods:**
1. Via ingress: `http://grafana.local` (with minikube tunnel)
2. Via port-forward: `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`

---

### 6. Node Exporter

```yaml
nodeExporter:
  enabled: true

  resources:
    limits:
      cpu: 100m
      memory: 128Mi
```

**Purpose:** Collects hardware and OS metrics from each node.

**What it monitors:**
- CPU usage, load average
- Memory usage, swap
- Disk I/O, space usage
- Network traffic
- File system stats

**Deployment:**
- Runs as DaemonSet (one pod per node)
- Minikube has 1 node = 1 Node Exporter pod

---

### 7. Kube State Metrics

```yaml
kubeStateMetrics:
  enabled: true

  resources:
    limits:
      cpu: 100m
      memory: 128Mi
```

**Purpose:** Exposes Kubernetes object state as metrics.

**What it monitors:**
- Pod status (Running, Pending, Failed)
- Deployment replicas (desired vs actual)
- Node conditions (Ready, DiskPressure)
- Resource requests and limits
- PersistentVolume status

**Why it's important:**
- Prometheus scrapes metrics, not Kubernetes API
- Provides cluster-wide visibility
- Essential for Kubernetes-specific alerts

---

### 8. Default Rules

```yaml
defaultRules:
  create: true
  rules:
    alertmanager: true
    general: true
    k8s: true
    node: true
    prometheus: true
```

**Purpose:** Pre-configured alerting rules for common issues.

**Enabled Rules:**
- **alertmanager:** Alertmanager health checks
- **general:** Generic Kubernetes alerts
- **k8s:** Kubernetes-specific alerts
- **node:** Node/server alerts
- **prometheus:** Prometheus self-monitoring

**Disabled Rules:**
```yaml
    etcd: false
    kubeProxy: false
    kubeScheduler: false
    kubeControllerManager: false
```

**Why disabled:**
- These components aren't accessible in Minikube
- Minikube uses different architecture than production
- Would generate false alerts

**Example alerts included:**
- Pod CrashLooping
- Node NotReady
- High memory usage
- Disk space low
- Prometheus scrape failures

---

## Resource Summary

### Total Resource Usage (Approximate)

**CPU Requests:** ~1.2 cores
- Prometheus: 250m
- Grafana: 100m
- Alertmanager: 50m
- Operator: 100m
- Exporters: ~200m
- Other: ~500m

**Memory Requests:** ~2.5 GB
- Prometheus: 1Gi
- Grafana: 256Mi
- Alertmanager: 128Mi
- Operator: 256Mi
- Exporters: ~400Mi
- Other: ~500Mi

**Storage:** ~17 GB
- Prometheus: 10Gi
- Grafana: 5Gi
- Alertmanager: 2Gi

**Minikube Requirements:**
- Minimum: 4GB RAM, 2 CPUs
- Recommended: 6GB RAM, 4 CPUs
- Storage: 20GB available

---

## Key Takeaways

1. **Resource Limits:** Prevent any single component from consuming all resources
2. **Persistent Storage:** Ensures data survives pod restarts
3. **Security Context:** Runs as non-root user for security
4. **Service Monitors:** Automatic discovery of metrics endpoints
5. **Pre-configured Dashboards:** Immediate visibility into cluster health
6. **Alerting Rules:** Proactive notification of issues
7. **Optimized for Minikube:** Reduced resources while maintaining functionality

---

## Production Differences

For production, you would typically:

1. **Increase Resources:**
   - Prometheus: 4-8GB RAM, 2-4 CPUs
   - Longer retention (30+ days)
   - Larger storage (100GB+)

2. **Enable High Availability:**
   - 2-3 Prometheus replicas
   - 3 Alertmanager replicas
   - Multiple Grafana instances

3. **Add Long-term Storage:**
   - Thanos or Cortex for multi-year retention
   - Remote write to external systems

4. **Enhanced Security:**
   - OAuth/SSO authentication
   - TLS encryption
   - Network policies
   - Pod Security Policies

5. **Advanced Alerting:**
   - Multiple notification channels
   - On-call rotations
   - Alert routing rules
   - Silence management

---

## Next Steps

After deploying with these values:

1. Access Grafana and explore dashboards
2. Create custom dashboards for your applications
3. Add ServiceMonitors for your services
4. Configure Alertmanager receivers (Slack, email)
5. Tune resource limits based on actual usage
6. Add custom alerting rules

---

**This configuration provides a solid foundation for monitoring your Kubernetes cluster while being resource-efficient for local development!**
