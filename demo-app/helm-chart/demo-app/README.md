# Demo App Helm Chart

A production-ready Helm chart for deploying the demo application with security, observability, and scalability best practices.

## TL;DR

```bash
# Install the chart
helm install demo-app ./demo-app \
  --namespace demo-app \
  --create-namespace

# Upgrade the chart
helm upgrade demo-app ./demo-app \
  --namespace demo-app

# Uninstall the chart
helm uninstall demo-app --namespace demo-app
```

## Introduction

This Helm chart deploys a production-ready Go web application with:
- **Security**: RBAC, SecurityContext, NetworkPolicies
- **Reliability**: Health checks, PodDisruptionBudget, Anti-affinity
- **Scalability**: HorizontalPodAutoscaler, Resource limits
- **Observability**: Prometheus metrics, ServiceMonitor

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Prometheus Operator (for ServiceMonitor)
- Ingress Controller (for Ingress)

## Installing the Chart

### Basic Installation

```bash
helm install demo-app ./demo-app \
  --namespace demo-app \
  --create-namespace
```

### With Custom Values

```bash
helm install demo-app ./demo-app \
  --namespace demo-app \
  --create-namespace \
  --values custom-values.yaml
```

### Development Environment

```bash
helm install demo-app ./demo-app \
  --namespace demo-app-dev \
  --create-namespace \
  --set environment=development \
  --set replicaCount=1 \
  --set ingress.hosts[0].host=demo-app-dev.local
```

### Production Environment

```bash
helm install demo-app ./demo-app \
  --namespace demo-app-prod \
  --create-namespace \
  --set environment=production \
  --set replicaCount=3 \
  --set autoscaling.maxReplicas=10 \
  --set ingress.hosts[0].host=demo-app.example.com \
  --set ingress.tls[0].secretName=demo-app-tls \
  --set ingress.tls[0].hosts[0]=demo-app.example.com
```

## Uninstalling the Chart

```bash
helm uninstall demo-app --namespace demo-app
```

## Configuration

The following table lists the configurable parameters and their default values.

### Application Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.name` | Application name | `demo-app` |
| `app.version` | Application version | `1.0.0` |
| `replicaCount` | Number of replicas | `2` |
| `image.repository` | Image repository | `demo-app` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Namespace Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.create` | Create namespace | `true` |
| `namespace.name` | Namespace name | `demo-app` |
| `namespace.labels` | Namespace labels | `{environment: development, managed-by: helm}` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `8080` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.hosts[0].host` | Hostname | `demo-app.local` |
| `ingress.tls` | TLS configuration | `[]` |

### Resource Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `256Mi` |

### Autoscaling Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Minimum replicas | `2` |
| `autoscaling.maxReplicas` | Maximum replicas | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU % | `70` |
| `autoscaling.targetMemoryUtilizationPercentage` | Target Memory % | `80` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext.runAsNonRoot` | Run as non-root | `true` |
| `podSecurityContext.runAsUser` | User ID | `65534` |
| `securityContext.readOnlyRootFilesystem` | Read-only filesystem | `true` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `true` |

### Monitoring Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceMonitor.enabled` | Enable ServiceMonitor | `true` |
| `serviceMonitor.interval` | Scrape interval | `30s` |
| `serviceMonitor.scrapeTimeout` | Scrape timeout | `10s` |

### Health Check Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe.initialDelaySeconds` | Liveness initial delay | `10` |
| `livenessProbe.periodSeconds` | Liveness period | `10` |
| `readinessProbe.initialDelaySeconds` | Readiness initial delay | `5` |
| `readinessProbe.periodSeconds` | Readiness period | `5` |

## Examples

### Example 1: Development Environment

Create `values-dev.yaml`:

```yaml
environment: development
replicaCount: 1

image:
  tag: dev-latest

ingress:
  hosts:
    - host: demo-app-dev.local
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi

autoscaling:
  enabled: false

configMap:
  data:
    ENVIRONMENT: "development"
    LOG_LEVEL: "debug"
```

Install:
```bash
helm install demo-app ./demo-app -f values-dev.yaml -n demo-app-dev --create-namespace
```

### Example 2: Staging Environment

Create `values-staging.yaml`:

```yaml
environment: staging
replicaCount: 2

image:
  tag: staging-v1.0.0

ingress:
  hosts:
    - host: demo-app-staging.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: demo-app-staging-tls
      hosts:
        - demo-app-staging.example.com

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5

configMap:
  data:
    ENVIRONMENT: "staging"
    LOG_LEVEL: "info"
```

Install:
```bash
helm install demo-app ./demo-app -f values-staging.yaml -n demo-app-staging --create-namespace
```

### Example 3: Production Environment

Create `values-prod.yaml`:

```yaml
environment: production
replicaCount: 3

image:
  repository: registry.example.com/demo-app
  tag: v1.0.0
  pullPolicy: Always

imagePullSecrets:
  - name: registry-credentials

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: demo-app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: demo-app-tls
      hosts:
        - demo-app.example.com

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 2

configMap:
  data:
    ENVIRONMENT: "production"
    LOG_LEVEL: "warn"

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values:
                - demo-app
        topologyKey: kubernetes.io/hostname
```

Install:
```bash
helm install demo-app ./demo-app -f values-prod.yaml -n demo-app-prod --create-namespace
```

## Upgrading

### Upgrade with New Values

```bash
helm upgrade demo-app ./demo-app \
  --namespace demo-app \
  --values new-values.yaml
```

### Upgrade with Set Values

```bash
helm upgrade demo-app ./demo-app \
  --namespace demo-app \
  --set image.tag=v1.1.0 \
  --set replicaCount=3
```

### Upgrade with Reuse Values

```bash
helm upgrade demo-app ./demo-app \
  --namespace demo-app \
  --reuse-values \
  --set image.tag=v1.1.0
```

## Rollback

### List Releases

```bash
helm history demo-app --namespace demo-app
```

### Rollback to Previous Version

```bash
helm rollback demo-app --namespace demo-app
```

### Rollback to Specific Revision

```bash
helm rollback demo-app 2 --namespace demo-app
```

## Testing

### Lint the Chart

```bash
helm lint ./demo-app
```

### Dry Run

```bash
helm install demo-app ./demo-app \
  --namespace demo-app \
  --dry-run \
  --debug
```

### Template Rendering

```bash
helm template demo-app ./demo-app \
  --namespace demo-app \
  --values values-dev.yaml
```

### Test Release

```bash
helm test demo-app --namespace demo-app
```

## Troubleshooting

### Check Release Status

```bash
helm status demo-app --namespace demo-app
```

### Get Release Values

```bash
helm get values demo-app --namespace demo-app
```

### Get Rendered Manifests

```bash
helm get manifest demo-app --namespace demo-app
```

### Debug Installation

```bash
helm install demo-app ./demo-app \
  --namespace demo-app \
  --dry-run \
  --debug \
  --values values.yaml
```

## Chart Structure

```
demo-app/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── README.md               # This file
├── templates/
│   ├── NOTES.txt          # Post-install notes
│   ├── _helpers.tpl       # Template helpers
│   ├── namespace.yaml     # Namespace
│   ├── configmap.yaml     # ConfigMap
│   ├── serviceaccount.yaml # ServiceAccount + RBAC
│   ├── deployment.yaml    # Deployment
│   ├── service.yaml       # Service
│   ├── ingress.yaml       # Ingress
│   ├── networkpolicy.yaml # NetworkPolicy
│   ├── servicemonitor.yaml # ServiceMonitor
│   ├── hpa.yaml           # HorizontalPodAutoscaler
│   └── pdb.yaml           # PodDisruptionBudget
└── .helmignore            # Files to ignore
```

## Best Practices

1. **Use Values Files**: Create separate values files for each environment
2. **Version Control**: Store values files in Git
3. **Secrets Management**: Use external secrets management (e.g., Sealed Secrets, External Secrets Operator)
4. **Resource Limits**: Always set resource requests and limits
5. **Health Checks**: Configure liveness and readiness probes
6. **Security**: Enable NetworkPolicies and SecurityContexts
7. **Monitoring**: Enable ServiceMonitor for Prometheus
8. **High Availability**: Use multiple replicas and PodDisruptionBudget
9. **Autoscaling**: Enable HPA for production workloads
10. **Testing**: Always test with `--dry-run` before applying

## Contributing

1. Make changes to templates or values
2. Test with `helm lint`
3. Test with `helm template`
4. Test with `helm install --dry-run`
5. Test in development environment
6. Submit pull request

## License

MIT

## Support

For issues and questions:
- GitHub Issues: https://github.com/example/demo-app/issues
- Email: sre@example.com
