#!/bin/bash
# CI/CD Setup Script for Local Minikube
# This script sets up Jenkins pipeline and ArgoCD for local development

set -e

echo "=========================================="
echo "CI/CD Setup for Local Minikube"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
echo "Step 1: Checking prerequisites..."
echo "-----------------------------------"

# Check Minikube
if minikube status | grep -q "Running"; then
    print_success "Minikube is running"
else
    print_error "Minikube is not running"
    echo "Start with: minikube start"
    exit 1
fi

# Check Jenkins
if kubectl get pod -n jenkins jenkins-0 -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then
    print_success "Jenkins is running"
else
    print_error "Jenkins is not running"
    exit 1
fi

# Check ArgoCD
if kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
    print_success "ArgoCD is running"
else
    print_error "ArgoCD is not running"
    exit 1
fi

# Check Git credentials
if kubectl get secret -n jenkins git-credentials >/dev/null 2>&1; then
    print_success "Git credentials configured in Jenkins"
else
    print_warning "Git credentials not found in Jenkins"
    echo "Please create 'git-credentials' in Jenkins UI"
fi

echo ""
echo "Step 2: Configuring Jenkins Pipeline..."
echo "-----------------------------------"

# Get Jenkins URL
JENKINS_URL="http://localhost:8080"
print_success "Jenkins URL: $JENKINS_URL"

echo ""
echo "To create the Jenkins pipeline job:"
echo "1. Open Jenkins: $JENKINS_URL"
echo "2. Click 'New Item'"
echo "3. Enter name: 'demo-app-ci-local'"
echo "4. Select: 'Pipeline'"
echo "5. Click 'OK'"
echo "6. Configure:"
echo "   - Description: 'CI pipeline for demo app (local)'"
echo "   - Pipeline:"
echo "     * Definition: Pipeline script from SCM"
echo "     * SCM: Git"
echo "     * Repository URL: https://github.com/getneo/CKA"
echo "     * Credentials: git-credentials"
echo "     * Branch: */main"
echo "     * Script Path: demo-app/Jenkinsfile.local"
echo "7. Click 'Save'"
echo ""

read -p "Press Enter when you've created the Jenkins job..."

echo ""
echo "Step 3: Syncing ArgoCD Application..."
echo "-----------------------------------"

# Check if ArgoCD app exists
if kubectl get application -n argocd demo-app-dev >/dev/null 2>&1; then
    print_success "ArgoCD application 'demo-app-dev' exists"

    # Get sync status
    SYNC_STATUS=$(kubectl get application -n argocd demo-app-dev -o jsonpath='{.status.sync.status}')
    echo "Current sync status: $SYNC_STATUS"

    # Trigger initial sync
    echo "Triggering initial sync..."
    kubectl patch application demo-app-dev -n argocd \
        --type merge \
        -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' \
        2>/dev/null || echo "Sync already in progress or completed"

    print_success "ArgoCD sync triggered"
else
    print_error "ArgoCD application 'demo-app-dev' not found"
    echo "Apply with: kubectl apply -f argocd/applications/demo-app-dev.yaml"
    exit 1
fi

echo ""
echo "Step 4: Waiting for namespace creation..."
echo "-----------------------------------"

# Wait for namespace
echo "Waiting for demo-app-dev namespace..."
for i in {1..30}; do
    if kubectl get namespace demo-app-dev >/dev/null 2>&1; then
        print_success "Namespace demo-app-dev created"
        break
    fi
    echo -n "."
    sleep 2
done

if ! kubectl get namespace demo-app-dev >/dev/null 2>&1; then
    print_warning "Namespace not created yet. You may need to sync manually in ArgoCD UI"
fi

echo ""
echo "Step 5: Verification..."
echo "-----------------------------------"

# Check ArgoCD app status
echo "ArgoCD Application Status:"
kubectl get application -n argocd demo-app-dev

echo ""
echo "Checking if pods are running..."
if kubectl get pods -n demo-app-dev >/dev/null 2>&1; then
    kubectl get pods -n demo-app-dev
else
    print_warning "No pods found yet. ArgoCD may still be syncing."
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Access Jenkins: http://localhost:8080"
echo "   kubectl port-forward -n jenkins svc/jenkins 8080:8080"
echo ""
echo "2. Access ArgoCD: https://localhost:8081"
echo "   kubectl port-forward -n argocd svc/argocd-server 8081:443"
echo "   Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "3. Test the pipeline:"
echo "   - Make a code change in demo-app/"
echo "   - Commit and push to Git"
echo "   - Jenkins will build and update manifests"
echo "   - ArgoCD will detect and deploy automatically"
echo ""
echo "4. Or trigger manually:"
echo "   - Jenkins: Click 'Build Now' in demo-app-ci-local job"
echo "   - ArgoCD: Click 'Sync' in demo-app-dev application"
echo ""
print_success "CI/CD setup complete! 🚀"

# Made with Bob
