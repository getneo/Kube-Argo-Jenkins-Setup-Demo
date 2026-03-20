#!/bin/bash

# Reinstall All Components Script
# This script reinstalls Jenkins, ArgoCD, and Prometheus after Minikube restart
# Run this after: minikube delete && minikube start --cpus=6 --memory=8192 --disk-size=30g

set -e  # Exit on error

echo "=========================================="
echo "Reinstalling All Kubernetes Components"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Minikube is running
echo "Checking Minikube status..."
if ! minikube status > /dev/null 2>&1; then
    print_error "Minikube is not running. Please start it first:"
    echo "  minikube start --cpus=6 --memory=8192 --disk-size=30g"
    exit 1
fi
print_status "Minikube is running"
echo ""

# Display current resources
echo "Current Minikube Resources:"
kubectl top nodes
echo ""

# Step 1: Create Namespaces
echo "=========================================="
echo "Step 1: Creating Namespaces"
echo "=========================================="
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo-app --dry-run=client -o yaml | kubectl apply -f -
print_status "Namespaces created"
echo ""

# Step 2: Apply Resource Quotas and Network Policies
echo "=========================================="
echo "Step 2: Applying Resource Quotas & Policies"
echo "=========================================="
if [ -d "k8s/setup" ]; then
    kubectl apply -f k8s/setup/resource-quota.yaml
    kubectl apply -f k8s/setup/limit-range.yaml
    kubectl apply -f k8s/setup/network-policies.yaml
    print_status "Resource quotas and network policies applied"
else
    print_warning "k8s/setup directory not found, skipping resource quotas"
fi
echo ""

# Step 3: Enable Ingress
echo "=========================================="
echo "Step 3: Enabling Ingress Controller"
echo "=========================================="
minikube addons enable ingress
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=120s
print_status "Ingress controller ready"
echo ""

# Step 4: Add Helm Repositories
echo "=========================================="
echo "Step 4: Adding Helm Repositories"
echo "=========================================="
helm repo add jenkins https://charts.jenkins.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
print_status "Helm repositories added and updated"
echo ""

# Step 5: Install Jenkins
echo "=========================================="
echo "Step 5: Installing Jenkins"
echo "=========================================="
if [ -f "jenkins/values-minimal.yaml" ]; then
    helm install jenkins jenkins/jenkins -n jenkins -f jenkins/values-minimal.yaml --wait --timeout 10m
    print_status "Jenkins installed"

    # Apply Jenkins network policy
    if [ -f "k8s/setup/jenkins-ingress-network-policy.yaml" ]; then
        kubectl apply -f k8s/setup/jenkins-ingress-network-policy.yaml
        print_status "Jenkins network policy applied"
    fi

    # Apply Jenkins ingress
    if [ -f "jenkins/ingress.yaml" ]; then
        kubectl apply -f jenkins/ingress.yaml
        print_status "Jenkins ingress applied"
    fi

    echo ""
    echo "Jenkins Access:"
    echo "  Port-forward: kubectl port-forward -n jenkins svc/jenkins 8080:8080"
    echo "  URL: http://localhost:8080"
    echo "  Username: admin"
    echo "  Password: Run 'kubectl get secret -n jenkins jenkins -o jsonpath=\"{.data.jenkins-admin-password}\" | base64 -d'"
else
    print_warning "jenkins/values-minimal.yaml not found, skipping Jenkins installation"
fi
echo ""

# Step 6: Install ArgoCD
echo "=========================================="
echo "Step 6: Installing ArgoCD"
echo "=========================================="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "Waiting for ArgoCD pods to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
print_status "ArgoCD installed"

# Apply ArgoCD network policy
if [ -f "k8s/setup/argocd-network-policy.yaml" ]; then
    kubectl apply -f k8s/setup/argocd-network-policy.yaml
    print_status "ArgoCD network policy applied"
fi

# Apply ArgoCD ingress
if [ -f "argocd/ingress.yaml" ]; then
    kubectl apply -f argocd/ingress.yaml
    print_status "ArgoCD ingress applied"
fi

echo ""
echo "ArgoCD Access:"
echo "  Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  URL: https://localhost:8080"
echo "  Username: admin"
echo "  Password: Run 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d'"
echo ""

# Step 7: Install Prometheus Stack
echo "=========================================="
echo "Step 7: Installing Prometheus & Grafana"
echo "=========================================="
if [ -f "monitoring/prometheus-values.yaml" ]; then
    helm install prometheus prometheus-community/kube-prometheus-stack \
        -n monitoring \
        -f monitoring/prometheus-values.yaml \
        --wait \
        --timeout 15m
    print_status "Prometheus and Grafana installed"

    echo ""
    echo "Grafana Access:"
    echo "  Port-forward: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "  URL: http://localhost:3000"
    echo "  Username: admin"
    echo "  Password: admin123"
else
    print_warning "monitoring/prometheus-values.yaml not found, skipping Prometheus installation"
fi
echo ""

# Step 8: Verify Installation
echo "=========================================="
echo "Step 8: Verifying Installation"
echo "=========================================="
echo ""
echo "Pods in jenkins namespace:"
kubectl get pods -n jenkins
echo ""
echo "Pods in argocd namespace:"
kubectl get pods -n argocd
echo ""
echo "Pods in monitoring namespace:"
kubectl get pods -n monitoring
echo ""

# Summary
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Configure Jenkins security (see docs/jenkins-security-setup-guide.md)"
echo "2. Change ArgoCD admin password"
echo "3. Access Grafana and explore dashboards"
echo "4. Create demo application"
echo "5. Set up CI/CD pipeline"
echo ""
echo "Quick Access Commands:"
echo "  Jenkins:    kubectl port-forward -n jenkins svc/jenkins 8080:8080"
echo "  ArgoCD:     kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  Grafana:    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo ""
print_status "All components installed successfully!"
