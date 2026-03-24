#!/bin/bash
# Local CI Build Script
# This script mimics what Jenkins would do, but runs on your local machine
# Use this for local development until Jenkins is properly configured with Docker access

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Local CI Build Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get version from user or use default
if [ -z "$1" ]; then
    echo -e "${YELLOW}No version specified. Usage: $0 <version>${NC}"
    echo -e "${YELLOW}Example: $0 1.0.1${NC}"
    echo ""
    echo -e "${YELLOW}Using default version based on git...${NC}"

    # Try to get latest tag
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    # Remove 'v' prefix if present
    LATEST_VERSION=${LATEST_TAG#v}

    # Increment patch version
    IFS='.' read -r -a VERSION_PARTS <<< "$LATEST_VERSION"
    MAJOR=${VERSION_PARTS[0]:-0}
    MINOR=${VERSION_PARTS[1]:-0}
    PATCH=${VERSION_PARTS[2]:-0}
    PATCH=$((PATCH + 1))

    APP_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    echo -e "${YELLOW}Suggested version: ${APP_VERSION}${NC}"
    echo -e "${YELLOW}Press Enter to use this version, or type a new one:${NC}"
    read -r USER_VERSION

    if [ -n "$USER_VERSION" ]; then
        APP_VERSION="$USER_VERSION"
    fi
else
    APP_VERSION="$1"
fi

# Validate semantic version format
if ! [[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Version must be in semantic format (e.g., 1.0.1)${NC}"
    exit 1
fi

APP_NAME="demo-app"
GIT_COMMIT_SHORT=$(git rev-parse --short HEAD)
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo -e "${GREEN}Build Information:${NC}"
echo "  App Name: ${APP_NAME}"
echo "  Version: ${APP_VERSION}"
echo "  Git Commit: ${GIT_COMMIT_SHORT}"
echo "  Build Time: ${BUILD_TIME}"
echo ""

# Stage 1: Checkout
echo -e "${BLUE}========== Stage 1: Checkout ==========${NC}"
cd "$(git rev-parse --show-toplevel)"
echo "✅ Repository root: $(pwd)"
echo ""

# Stage 2: Docker Build
echo -e "${BLUE}========== Stage 2: Docker Build ==========${NC}"
cd demo-app

echo "Setting up Minikube Docker environment..."
eval $(minikube docker-env)

echo "Building Docker image: ${APP_NAME}:${APP_VERSION}"
docker build \
    --build-arg VERSION="${APP_VERSION}" \
    --build-arg BUILD_TIME="${BUILD_TIME}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT_SHORT}" \
    -t ${APP_NAME}:${APP_VERSION} .

# Tag with additional tags
docker tag ${APP_NAME}:${APP_VERSION} ${APP_NAME}:latest
docker tag ${APP_NAME}:${APP_VERSION} ${APP_NAME}:${GIT_COMMIT_SHORT}

echo ""
echo "✅ Docker images built:"
docker images | grep ${APP_NAME} | head -5
echo ""

# Stage 3: Security Scan (optional)
echo -e "${BLUE}========== Stage 3: Security Scan ==========${NC}"
if command -v trivy &> /dev/null; then
    echo "Running Trivy security scan..."
    trivy image --severity HIGH,CRITICAL ${APP_NAME}:${APP_VERSION} || true
else
    echo -e "${YELLOW}⚠️  Trivy not installed, skipping security scan${NC}"
    echo "Install: brew install trivy (macOS)"
fi
echo ""

# Stage 4: Update Manifests
echo -e "${BLUE}========== Stage 4: Update Manifests ==========${NC}"
cd helm-chart/demo-app

echo "Updating Helm values with new image tag..."

# Update dev environment (uses latest)
sed -i.bak "s/tag: \".*\"/tag: \"latest\"/" values-dev.yaml
rm values-dev.yaml.bak

# Update staging environment (uses latest)
sed -i.bak "s/tag: \".*\"/tag: \"latest\"/" values.yaml
rm values.yaml.bak

echo "Updated values-dev.yaml and values.yaml to use 'latest'"
echo ""
echo -e "${YELLOW}Note: Production (values-prod.yaml) should be updated manually${NC}"
echo -e "${YELLOW}      with specific version: ${APP_VERSION}${NC}"
echo ""

# Stage 5: Git Commit and Push
echo -e "${BLUE}========== Stage 5: Git Commit & Push ==========${NC}"
git add values-dev.yaml values.yaml

if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "chore: update demo-app image to ${APP_VERSION} [skip ci]"

    echo ""
    echo -e "${YELLOW}Ready to push to Git. Push now? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        git push origin main
        echo "✅ Changes pushed to Git"
    else
        echo "⚠️  Changes committed but not pushed. Run 'git push' manually."
    fi
fi
echo ""

# Stage 6: Create Git Tag
echo -e "${BLUE}========== Stage 6: Create Git Tag ==========${NC}"
echo -e "${YELLOW}Create git tag v${APP_VERSION}? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    git tag -a "v${APP_VERSION}" -m "Release v${APP_VERSION}"
    echo "✅ Tag v${APP_VERSION} created"

    echo -e "${YELLOW}Push tag to remote? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        git push origin "v${APP_VERSION}"
        echo "✅ Tag pushed to remote"
    fi
else
    echo "⚠️  Tag not created"
fi
echo ""

# Stage 7: Restart Deployments
echo -e "${BLUE}========== Stage 7: Restart Deployments ==========${NC}"
echo "Restarting dev and staging deployments..."
kubectl rollout restart deployment/demo-app-dev -n demo-app-dev 2>/dev/null || echo "⚠️  demo-app-dev not found"
kubectl rollout restart deployment/demo-app-staging -n demo-app-staging 2>/dev/null || echo "⚠️  demo-app-staging not found"
echo ""

echo -e "${YELLOW}Note: Production deployment requires manual update${NC}"
echo "To deploy to production:"
echo "  1. Edit demo-app/helm-chart/demo-app/values-prod.yaml"
echo "  2. Change image.tag to \"${APP_VERSION}\""
echo "  3. Commit and push"
echo "  4. Manually sync in ArgoCD"
echo ""

echo "Waiting for dev rollout to complete..."
kubectl rollout status deployment/demo-app-dev -n demo-app-dev --timeout=60s 2>/dev/null || echo "⚠️  Timeout or deployment not found"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build Complete! ✅${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Image: ${APP_NAME}:${APP_VERSION}"
echo "Commit: ${GIT_COMMIT_SHORT}"
echo "Tags: ${APP_VERSION}, latest, ${GIT_COMMIT_SHORT}"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n demo-app-dev"
echo "  kubectl get pods -n demo-app-staging"
echo ""
echo "Test the application:"
echo "  kubectl port-forward -n demo-app-dev svc/demo-app-dev 8082:80 &"
echo "  curl http://localhost:8082/health"
echo ""
echo "ArgoCD will detect the manifest change and sync automatically."
echo "Check ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8081:443 &"
echo ""
echo -e "${YELLOW}For production deployment, see instructions above.${NC}"
echo ""

# Made with Bob
