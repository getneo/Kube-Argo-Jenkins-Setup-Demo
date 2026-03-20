# Prometheus and Grafana Monitoring Stack - Access Information

## Overview

The Prometheus monitoring stack has been successfully installed in the `monitoring` namespace with the following components:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert management
- **Node Exporter**: Host metrics collection
- **Kube State Metrics**: Kubernetes object metrics
- **Prometheus Operator**: Manages Prometheus instances

## Component Status

```bash
kubectl get pods -n monitoring
```

All components should show READY status:
- `prometheus-prometheus-kube-prometheus-prometheus-0`: 2/2 Running
- `alertmanager-prometheus-kube-prometheus-alertmanager-0`: 2/2 Running
- `prometheus-grafana-*`: 3/3 Running
- `prometheus-prometheus-node-exporter-*`: 1/1 Running
- `prometheus-kube-state-metrics-*`: 1/1 Running
- `prometheus-kube-prometheus-operator-*`: 1/1 Running

## Access Methods

### 1. Grafana Dashboard

**Port Forward Method:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

**Access URL:** http://localhost:3000

**Credentials:**
- Username: `admin`
- Password: ``

**Pre-installed Dashboards:**
- Kubernetes Cluster Monitoring (ID: 7249)
- Kubernetes Pods Monitoring (ID: 6417)
- Node Exporter Full (ID: 1860)

### 2. Prometheus UI

**Port Forward Method:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

**Access URL:** http://localhost:9090

**Features:**
- Query metrics using PromQL
- View targets and service discovery
- Check alerting rules
- Explore time-series data

### 3. Alertmanager UI

**Port Forward Method:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

**Access URL:** http://localhost:9093

**Features:**
- View active alerts
- Manage alert silences
- Configure alert routing

## Ingress Access (Optional)

If you want to access Grafana via ingress (grafana.local):

1. Ensure `minikube tunnel` is running
2. Add to `/etc/hosts`:
   ```
   127.0.0.1 grafana.local
   ```
3. Access: http://grafana.local

## Monitoring Configuration

### Resource Allocation

The stack is configured with minimal resources for local development:

**Prometheus:**
- CPU Request: 50m
- Memory Request: 256Mi
- CPU Limit: 200m
- Memory Limit: 512Mi

**Config Reloader (sidecar):**
- CPU Request: 50m
- Memory Request: 50Mi
- CPU Limit: 100m
- Memory Limit: 100Mi

**Alertmanager:**
- CPU Request: 50m
- Memory Request: 128Mi
- CPU Limit: 100m
- Memory Limit: 256Mi

**Grafana:**
- CPU Request: 100m
- Memory Request: 256Mi
- CPU Limit: 200m
- Memory Limit: 512Mi

### Data Retention

- **Prometheus Retention**: 7 days
- **Prometheus Storage**: 10Gi PVC
- **Alertmanager Storage**: 2Gi PVC
- **Grafana Storage**: 5Gi PVC

### Scrape Configuration

- **Scrape Interval**: 30 seconds
- **Evaluation Interval**: 30 seconds
- **Service Monitor Selector**: All namespaces
- **Pod Monitor Selector**: All namespaces

## Verification Commands

### Check All Services
```bash
kubectl get svc -n monitoring
```

### Check Prometheus Targets
```bash
# Port forward first
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Then visit: http://localhost:9090/targets
```

### Check Grafana Datasources
```bash
# Port forward first
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Login and go to: Configuration > Data Sources
```

### View Prometheus Metrics
```bash
# Example: Check node CPU usage
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Query in Prometheus UI:
# node_cpu_seconds_total
# rate(node_cpu_seconds_total[5m])
```

## Troubleshooting

### Pods Not Starting

1. **Check resource availability:**
   ```bash
   kubectl describe node minikube | grep -A 5 "Allocated resources"
   ```

2. **Check pod events:**
   ```bash
   kubectl describe pod <pod-name> -n monitoring
   ```

3. **Check for LimitRange restrictions:**
   ```bash
   kubectl get limitrange -n monitoring
   # If exists and blocking, delete it:
   kubectl delete limitrange default-limits -n monitoring
   ```

### Prometheus Not Scraping Targets

1. **Check ServiceMonitor resources:**
   ```bash
   kubectl get servicemonitor -n monitoring
   ```

2. **Check Prometheus logs:**
   ```bash
   kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus
   ```

3. **Verify network policies allow scraping:**
   ```bash
   kubectl get networkpolicy -n monitoring
   ```

### Grafana Dashboard Not Loading

1. **Check Grafana logs:**
   ```bash
   kubectl logs -n monitoring deployment/prometheus-grafana -c grafana
   ```

2. **Verify datasource configuration:**
   ```bash
   kubectl get secret -n monitoring prometheus-grafana -o yaml
   ```

3. **Reset admin password if needed:**
   ```bash
   kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
   ```

## Monitoring Best Practices

### 1. Resource Monitoring
- Monitor CPU, memory, disk, and network usage
- Set up alerts for resource exhaustion
- Track pod restart counts

### 2. Application Metrics
- Expose application metrics on `/metrics` endpoint
- Use Prometheus client libraries
- Create ServiceMonitors for automatic discovery

### 3. Alert Configuration
- Define meaningful alert thresholds
- Avoid alert fatigue with proper grouping
- Test alerts regularly

### 4. Dashboard Organization
- Create separate dashboards per service
- Use variables for dynamic filtering
- Document dashboard purpose and queries

## Next Steps

1. **Create Custom Dashboards**: Build dashboards for your applications
2. **Configure Alerts**: Set up alerting rules for critical metrics
3. **Add ServiceMonitors**: Enable monitoring for your applications
4. **Integrate with Applications**: Add Prometheus client libraries to your apps
5. **Set Up Alert Routing**: Configure Alertmanager for notifications (email, Slack, etc.)

## Related Documentation

- [Prometheus Values Configuration](../monitoring/prometheus-values.yaml)
- [Prometheus Values Explanation](./prometheus-values-explanation.md)
- [Jenkins Access Info](./jenkins-access-info.md)
- [ArgoCD Access Info](./argocd-access-info.md)

## Useful Links

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Kube-Prometheus-Stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
