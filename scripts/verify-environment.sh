#!/bin/bash
# Environment Verification Script
# Comprehensive checks for Kubernetes CI/CD environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Environment Verification Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((FAILED++))
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING${NC}: $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ INFO${NC}: $1"
}

# Section header
section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# 1. Check Docker
section "Docker Verification"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_status 0 "Docker installed (version: $DOCKER_VERSION)"

    if docker ps &> /dev/null; then
        print_status 0 "Docker daemon is running"
    else
        print_status 1 "Docker daemon is not running"
    fi
else
    print_status 1 "Docker is not installed"
fi

# 2. Check kubectl
section "kubectl Verification"
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion')
    print_status 0 "kubectl installed (version: $KUBECTL_VERSION)"

    if kubectl cluster-info &> /dev/null; then
        print_status 0 "kubectl can connect to cluster"
        CLUSTER_VERSION=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion')
        print_info "Cluster version: $CLUSTER_VERSION"
    else
        print_status 1 "kubectl cannot connect to cluster"
    fi
else
    print_status 1 "kubectl is not installed"
fi

# 3. Check Minikube
section "Minikube Verification"
if command -v minikube &> /dev/null; then
    MINIKUBE_VERSION=$(minikube version --short)
    print_status 0 "Minikube installed (version: $MINIKUBE_VERSION)"

    MINIKUBE_STATUS=$(minikube status -o json 2>/dev/null | jq -r '.Host')
    if [ "$MINIKUBE_STATUS" == "Running" ]; then
        print_status 0 "Minikube cluster is running"
        MINIKUBE_IP=$(minikube ip 2>/dev/null)
        print_info "Minikube IP: $MINIKUBE_IP"
    else
        print_status 1 "Minikube cluster is not running"
    fi
else
    print_status 1 "Minikube is not installed"
fi

# 4. Check Helm
section "Helm Verification"
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short)
    print_status 0 "Helm installed (version: $HELM_VERSION)"
else
    print_status 1 "Helm is not installed"
fi

# 5. Check Additional Tools
section "Additional Tools Verification"
TOOLS=("kubectx" "kubens" "k9s" "jq" "yq" "stern" "kustomize")
for tool in "${TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        print_status 0 "$tool is installed"
    else
        print_warning "$tool is not installed (optional but recommended)"
    fi
done

# 6. Check Cluster Nodes
section "Cluster Nodes"
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NODE_COUNT" -gt 0 ]; then
    print_status 0 "Cluster has $NODE_COUNT node(s)"

    READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    if [ "$READY_NODES" -eq "$NODE_COUNT" ]; then
        print_status 0 "All nodes are Ready"
    else
        print_status 1 "Not all nodes are Ready ($READY_NODES/$NODE_COUNT)"
    fi
else
    print_status 1 "No nodes found in cluster"
fi

# 7. Check System Pods
section "System Pods"
SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$SYSTEM_PODS" -gt 0 ]; then
    print_status 0 "Found $SYSTEM_PODS system pods"

    RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$RUNNING_PODS" -eq "$SYSTEM_PODS" ]; then
        print_status 0 "All system pods are Running"
    else
        print_warning "Not all system pods are Running ($RUNNING_PODS/$SYSTEM_PODS)"
    fi
else
    print_status 1 "No system pods found"
fi

# 8. Check Namespaces
section "Required Namespaces"
REQUIRED_NS=("jenkins" "argocd" "monitoring" "demo-app")
for ns in "${REQUIRED_NS[@]}"; do
    if kubectl get namespace $ns &> /dev/null; then
        print_status 0 "Namespace '$ns' exists"
    else
        print_status 1 "Namespace '$ns' does not exist"
    fi
done

# 9. Check Resource Quotas
section "Resource Quotas"
QUOTA_COUNT=$(kubectl get resourcequota -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$QUOTA_COUNT" -gt 0 ]; then
    print_status 0 "Found $QUOTA_COUNT resource quotas"
else
    print_warning "No resource quotas configured"
fi

# 10. Check Limit Ranges
section "Limit Ranges"
LIMIT_COUNT=$(kubectl get limitrange -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$LIMIT_COUNT" -gt 0 ]; then
    print_status 0 "Found $LIMIT_COUNT limit ranges"
else
    print_warning "No limit ranges configured"
fi

# 11. Check Network Policies
section "Network Policies"
NP_COUNT=$(kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NP_COUNT" -gt 0 ]; then
    print_status 0 "Found $NP_COUNT network policies"
else
    print_warning "No network policies configured"
fi

# 12. Check Storage Classes
section "Storage Classes"
SC_COUNT=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$SC_COUNT" -gt 0 ]; then
    print_status 0 "Found $SC_COUNT storage class(es)"

    DEFAULT_SC=$(kubectl get storageclass --no-headers 2>/dev/null | grep "(default)" | awk '{print $1}')
    if [ -n "$DEFAULT_SC" ]; then
        print_status 0 "Default storage class: $DEFAULT_SC"
    else
        print_warning "No default storage class configured"
    fi
else
    print_status 1 "No storage classes found"
fi

# 13. Check Metrics Server
section "Metrics Server"
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    print_status 0 "Metrics server deployment exists"

    METRICS_READY=$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [ "$METRICS_READY" -gt 0 ]; then
        print_status 0 "Metrics server is ready"

        if kubectl top nodes &> /dev/null; then
            print_status 0 "Metrics server is functional"
        else
            print_warning "Metrics server exists but metrics not available yet"
        fi
    else
        print_status 1 "Metrics server is not ready"
    fi
else
    print_status 1 "Metrics server is not installed"
fi

# 14. Check Ingress Controller
section "Ingress Controller"
if kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -q "ingress-nginx-controller"; then
    print_status 0 "Ingress controller is installed"

    INGRESS_READY=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep "ingress-nginx-controller" | grep -c "Running" || echo "0")
    if [ "$INGRESS_READY" -gt 0 ]; then
        print_status 0 "Ingress controller is running"
    else
        print_status 1 "Ingress controller is not running"
    fi
else
    print_status 1 "Ingress controller is not installed"
fi

# 15. Check Minikube Addons
section "Minikube Addons"
if command -v minikube &> /dev/null; then
    REQUIRED_ADDONS=("metrics-server" "ingress" "dashboard" "default-storageclass")
    for addon in "${REQUIRED_ADDONS[@]}"; do
        if minikube addons list 2>/dev/null | grep -q "$addon.*enabled"; then
            print_status 0 "Addon '$addon' is enabled"
        else
            print_warning "Addon '$addon' is not enabled"
        fi
    done
fi

# 16. Check Resource Availability
section "Resource Availability"
if kubectl top nodes &> /dev/null; then
    NODE_CPU=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $3}' | sed 's/%//')
    NODE_MEM=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $5}' | sed 's/%//')

    print_info "Node CPU usage: ${NODE_CPU}%"
    print_info "Node Memory usage: ${NODE_MEM}%"

    if [ "$NODE_CPU" -lt 80 ]; then
        print_status 0 "CPU resources available"
    else
        print_warning "High CPU usage (${NODE_CPU}%)"
    fi

    if [ "$NODE_MEM" -lt 80 ]; then
        print_status 0 "Memory resources available"
    else
        print_warning "High memory usage (${NODE_MEM}%)"
    fi
fi

# 17. Check Configuration Files
section "Configuration Files"
CONFIG_FILES=(
    "jenkins/values.yaml"
    "k8s/setup/resource-quota.yaml"
    "k8s/setup/limit-range.yaml"
    "k8s/setup/network-policies.yaml"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status 0 "Configuration file exists: $file"
    else
        print_warning "Configuration file missing: $file"
    fi
done

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Environment verification completed successfully!${NC}"
    echo -e "${GREEN}  Your environment is ready for Jenkins installation.${NC}"
    exit 0
else
    echo -e "${RED}✗ Environment verification found issues.${NC}"
    echo -e "${RED}  Please fix the failed checks before proceeding.${NC}"
    exit 1
fi
