# 01 - Environment Setup

## Overview

This guide covers the installation and configuration of Minikube and essential Kubernetes tools on macOS. We'll set up a production-like local Kubernetes environment following SRE best practices.

---

## Prerequisites

### System Requirements
- **OS**: macOS (Intel or Apple Silicon)
- **RAM**: Minimum 8GB (16GB recommended)
- **Disk Space**: 20GB free space
- **Docker**: Docker Desktop installed and running
- **Homebrew**: Package manager for macOS

### Verify Docker Installation

```bash
# Check Docker is running
docker --version
docker ps

# Expected output:
# Docker version 24.x.x or higher
```

---

## 1. Install Essential Tools

### 1.1 Install kubectl (Kubernetes CLI)

```bash
# Install kubectl via Homebrew
brew install kubectl

# Verify installation
kubectl version --client

# Expected output:
# Client Version: v1.28.x or higher
```

### 1.2 Install Minikube

```bash
# Install Minikube
brew install minikube

# Verify installation
minikube version

# Expected output:
# minikube version: v1.32.x or higher
```

### 1.3 Install Helm (Kubernetes Package Manager)

```bash
# Install Helm
brew install helm

# Verify installation
helm version

# Expected output:
# version.BuildInfo{Version:"v3.13.x" or higher}
```

### 1.4 Install Additional Tools

```bash
# Install kubectx and kubens for context switching
brew install kubectx

# Install k9s for terminal UI
brew install k9s

# Install jq for JSON processing
brew install jq

# Install yq for YAML processing
brew install yq

# Install stern for multi-pod log tailing
brew install stern

# Install kustomize
brew install kustomize
```

---

## 2. Configure Minikube

### 2.1 Start Minikube Cluster

```bash
# Start Minikube with recommended settings
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --driver=docker \
  --kubernetes-version=v1.28.0 \
  --addons=metrics-server,ingress,dashboard

# This will:
# - Allocate 4 CPU cores
# - Allocate 8GB RAM
# - Create 40GB disk
# - Use Docker as the driver
# - Install Kubernetes v1.28.0
# - Enable metrics-server for HPA
# - Enable ingress controller
# - Enable Kubernetes dashboard
```

**Note**: Adjust CPU and memory based on your system resources.

### 2.2 Verify Cluster Status

```bash
# Check cluster status
minikube status

# Expected output:
# minikube
# type: Control Plane
# host: Running
# kubelet: Running
# apiserver: Running
# kubeconfig: Configured

# Check nodes
kubectl get nodes

# Expected output:
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.28.0

# Check system pods
kubectl get pods -n kube-system

# All pods should be in Running state
```

### 2.3 Configure kubectl Context

```bash
# Set current context to minikube
kubectl config use-context minikube

# Verify current context
kubectl config current-context

# Expected output: minikube

# View cluster info
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://127.0.0.1:xxxxx
# CoreDNS is running at https://127.0.0.1:xxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

---

## 3. Enable Minikube Addons

### 3.1 Essential Addons

```bash
# Enable metrics-server (for HPA and resource monitoring)
minikube addons enable metrics-server

# Enable ingress (NGINX Ingress Controller)
minikube addons enable ingress

# Enable dashboard (Kubernetes Web UI)
minikube addons enable dashboard

# Enable storage-provisioner (for PersistentVolumes)
minikube addons enable storage-provisioner

# Enable default-storageclass
minikube addons enable default-storageclass

# List all enabled addons
minikube addons list
```

### 3.2 Verify Addons

```bash
# Check metrics-server
kubectl get deployment metrics-server -n kube-system

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check storage class
kubectl get storageclass

# Expected output:
# NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
# standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  5m
```

---

## 4. Create Namespaces

### 4.1 Create Namespace Structure

```bash
# Create namespaces for different components
kubectl create namespace jenkins
kubectl create namespace argocd
kubectl create namespace monitoring
kubectl create namespace demo-app

# Verify namespaces
kubectl get namespaces

# Label namespaces for better organization
kubectl label namespace jenkins environment=ci-cd
kubectl label namespace argocd environment=ci-cd
kubectl label namespace monitoring environment=observability
kubectl label namespace demo-app environment=development
```

### 4.2 Set Default Namespace (Optional)

```bash
# Set demo-app as default namespace for convenience
kubectl config set-context --current --namespace=demo-app

# Verify
kubectl config view --minify | grep namespace:
```

---

## 5. Configure Resource Quotas and Limits

### 5.1 Create ResourceQuota for Namespaces

Create a file `resource-quota.yaml`:

```yaml
# Jenkins namespace quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: jenkins-quota
  namespace: jenkins
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "6"
    limits.memory: 12Gi
    persistentvolumeclaims: "5"
---
# ArgoCD namespace quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: argocd-quota
  namespace: argocd
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 6Gi
---
# Monitoring namespace quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: monitoring-quota
  namespace: monitoring
spec:
  hard:
    requests.cpu: "3"
    requests.memory: 6Gi
    limits.cpu: "5"
    limits.memory: 10Gi
    persistentvolumeclaims: "10"
---
# Demo app namespace quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-app-quota
  namespace: demo-app
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "3"
    limits.memory: 4Gi
    pods: "10"
```

Apply the quotas:

```bash
kubectl apply -f resource-quota.yaml

# Verify quotas
kubectl get resourcequota -A
```

### 5.2 Create LimitRange for Default Limits

Create a file `limit-range.yaml`:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: demo-app
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

Apply the limit range:

```bash
kubectl apply -f limit-range.yaml

# Verify
kubectl describe limitrange default-limits -n demo-app
```

---

## 6. Configure Persistent Storage

### 6.1 Verify Storage Class

```bash
# Check available storage classes
kubectl get storageclass

# Describe the default storage class
kubectl describe storageclass standard
```

### 6.2 Test PersistentVolume Creation

Create a test PVC:

```yaml
# test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: demo-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
```

```bash
# Apply test PVC
kubectl apply -f test-pvc.yaml

# Verify PVC is bound
kubectl get pvc -n demo-app

# Expected output:
# NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# test-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWO            standard       10s

# Clean up test PVC
kubectl delete pvc test-pvc -n demo-app
```

---

## 7. Configure Network Policies (Optional but Recommended)

### 7.1 Enable Network Policy Support

```bash
# Minikube uses Kindnet by default which supports NetworkPolicies
# Verify network plugin
kubectl get pods -n kube-system | grep -i network
```

### 7.2 Create Default Deny Policy

Create `default-deny-policy.yaml`:

```yaml
# Deny all ingress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: demo-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
# Deny all egress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: demo-app
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

```bash
# Apply network policies
kubectl apply -f default-deny-policy.yaml

# Note: We'll create specific allow policies for each application
```

---

## 8. Install Metrics Server (if not enabled)

```bash
# If metrics-server addon is not working, install manually
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server for Minikube (disable TLS verification)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for metrics-server to be ready
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Verify metrics are available
kubectl top nodes
kubectl top pods -A
```

---

## 9. Configure Ingress Controller

### 9.1 Verify Ingress Controller

```bash
# Check ingress-nginx pods
kubectl get pods -n ingress-nginx

# Get ingress controller service
kubectl get svc -n ingress-nginx

# Expected output:
# NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
# ingress-nginx-controller             NodePort    10.96.xxx.xxx   <none>        80:xxxxx/TCP,443:xxxxx/TCP   5m
```

### 9.2 Get Minikube IP for Ingress

```bash
# Get Minikube IP
minikube ip

# This IP will be used to access services via Ingress
# Example: 192.168.49.2

# You can also use minikube tunnel for LoadBalancer services
# Run in a separate terminal:
# minikube tunnel
```

### 9.3 Configure /etc/hosts (Optional)

```bash
# Add entries to /etc/hosts for local DNS resolution
# Replace <MINIKUBE_IP> with your actual Minikube IP

sudo bash -c 'cat >> /etc/hosts << EOF
# Minikube local development
<MINIKUBE_IP> jenkins.local
<MINIKUBE_IP> argocd.local
<MINIKUBE_IP> grafana.local
<MINIKUBE_IP> prometheus.local
<MINIKUBE_IP> demo-app.local
EOF'

# Verify
cat /etc/hosts | grep local
```

---

## 10. Useful Minikube Commands

### 10.1 Cluster Management

```bash
# Stop Minikube cluster
minikube stop

# Start existing cluster
minikube start

# Delete cluster (WARNING: This deletes all data)
minikube delete

# Pause cluster (saves resources)
minikube pause

# Unpause cluster
minikube unpause

# SSH into Minikube node
minikube ssh

# Get Minikube IP
minikube ip

# Open Kubernetes dashboard
minikube dashboard
```

### 10.2 Resource Management

```bash
# Check cluster resource usage
kubectl top nodes
kubectl top pods -A

# View cluster events
kubectl get events -A --sort-by='.lastTimestamp'

# Check cluster component status
kubectl get componentstatuses
```

### 10.3 Troubleshooting

```bash
# View Minikube logs
minikube logs

# View last 50 lines
minikube logs --length=50

# Check Minikube status
minikube status

# Validate cluster
kubectl cluster-info dump
```

---

## 11. Create Helper Scripts

### 11.1 Cluster Setup Script

Create `scripts/setup-cluster.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Setting up Minikube cluster..."

# Start Minikube
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --driver=docker \
  --kubernetes-version=v1.28.0

# Enable addons
echo "📦 Enabling addons..."
minikube addons enable metrics-server
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable storage-provisioner

# Create namespaces
echo "📁 Creating namespaces..."
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo-app --dry-run=client -o yaml | kubectl apply -f -

# Label namespaces
kubectl label namespace jenkins environment=ci-cd --overwrite
kubectl label namespace argocd environment=ci-cd --overwrite
kubectl label namespace monitoring environment=observability --overwrite
kubectl label namespace demo-app environment=development --overwrite

# Wait for metrics-server
echo "⏳ Waiting for metrics-server..."
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Wait for ingress controller
echo "⏳ Waiting for ingress controller..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=120s

echo "✅ Cluster setup complete!"
echo ""
echo "Cluster Info:"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes
echo ""
echo "Namespaces:"
kubectl get namespaces
echo ""
echo "Minikube IP: $(minikube ip)"
```

Make it executable:

```bash
chmod +x scripts/setup-cluster.sh
```

### 11.2 Cluster Cleanup Script

Create `scripts/cleanup-cluster.sh`:

```bash
#!/bin/bash
set -e

echo "🧹 Cleaning up Minikube cluster..."

# Delete namespaces (this will delete all resources in them)
kubectl delete namespace jenkins --ignore-not-found=true
kubectl delete namespace argocd --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true
kubectl delete namespace demo-app --ignore-not-found=true

echo "✅ Cleanup complete!"
```

Make it executable:

```bash
chmod +x scripts/cleanup-cluster.sh
```

---

## 12. Verification Checklist

Before proceeding to the next section, verify:

- [ ] Minikube cluster is running
- [ ] kubectl can communicate with the cluster
- [ ] All system pods are in Running state
- [ ] Metrics-server is working (`kubectl top nodes`)
- [ ] Ingress controller is running
- [ ] All namespaces are created
- [ ] Storage class is available
- [ ] Resource quotas are applied

### Verification Commands

```bash
# Run all verification checks
echo "=== Cluster Status ==="
minikube status

echo -e "\n=== Nodes ==="
kubectl get nodes

echo -e "\n=== System Pods ==="
kubectl get pods -n kube-system

echo -e "\n=== Namespaces ==="
kubectl get namespaces

echo -e "\n=== Storage Classes ==="
kubectl get storageclass

echo -e "\n=== Metrics ==="
kubectl top nodes

echo -e "\n=== Ingress Controller ==="
kubectl get pods -n ingress-nginx

echo -e "\n=== Resource Quotas ==="
kubectl get resourcequota -A

echo -e "\n✅ All checks complete!"
```

---

## 13. Common Issues and Solutions

### Issue 1: Minikube won't start

```bash
# Solution: Delete and recreate cluster
minikube delete
minikube start --cpus=4 --memory=8192 --driver=docker
```

### Issue 2: Metrics not available

```bash
# Solution: Restart metrics-server
kubectl rollout restart deployment metrics-server -n kube-system
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s
```

### Issue 3: Ingress not working

```bash
# Solution: Verify ingress addon and controller
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

### Issue 4: Out of resources

```bash
# Solution: Increase Minikube resources
minikube stop
minikube delete
minikube start --cpus=6 --memory=12288 --disk-size=50g --driver=docker
```

---

## Next Steps

Now that your Kubernetes cluster is set up, proceed to:
- **[02-jenkins-setup.md](./02-jenkins-setup.md)** - Install and configure Jenkins for CI

---

## Additional Resources

- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)