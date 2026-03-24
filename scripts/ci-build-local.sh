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

# Parse flags
SKIP_BUILD=false
SKIP_PUSH=false
APP_VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-push)
            SKIP_PUSH=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [VERSION] [OPTIONS]"
            echo ""
            echo "Arguments:"
            echo "  VERSION          Semantic version (e.g., 1.0.1). If omitted, auto-increments from git tags"
            echo ""
            echo "Options:"
            echo "  --skip-build     Skip Docker build stage (use existing image)"
            echo "  --skip-push      Skip git push (commit only)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 1.0.1                    # Build and deploy version 1.0.1"
            echo "  $0 1.0.1 --skip-build       # Update manifests only (image exists)"
            echo "  $0 --skip-build             # Auto-increment version, skip build"
            echo "  $0 1.0.1 --skip-push        # Build but don't push to git"
            exit 0
            ;;
        *)
            if [[ -z "$APP_VERSION" ]]; then
                APP_VERSION="$1"
            else
                echo -e "${RED}Error: Unknown argument: $1${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Local CI Build Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get version from user or use default
if [ -z "$APP_VERSION" ]; then
    echo -e "${YELLOW}No version specified.${NC}"
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
if [ "$SKIP_BUILD" = true ]; then
    echo -e "${YELLOW}⚠️  Skipping Docker build (--skip-build flag)${NC}"
    echo "Using existing image: ${APP_NAME}:${APP_VERSION}"

    # Verify image exists
    eval $(minikube docker-env)
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${APP_NAME}:${APP_VERSION}$"; then
        echo -e "${RED}Error: Image ${APP_NAME}:${APP_VERSION} not found!${NC}"
        echo "Available images:"
        docker images | grep ${APP_NAME}
        exit 1
    fi
    echo "✅ Image verified"
else
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
fi
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
cd "$(git rev-parse --show-toplevel)/demo-app/helm-chart/demo-app"

echo "Updating Helm values with new image tag: ${APP_VERSION}"

# Update dev environment (uses semantic version)
sed -i.bak "s/tag: \".*\"/tag: \"${APP_VERSION}\"/" values-dev.yaml
rm values-dev.yaml.bak

# Update staging environment (uses semantic version)
sed -i.bak "s/tag: \".*\"/tag: \"${APP_VERSION}\"/" values.yaml
rm values.yaml.bak

echo "✅ Updated values-dev.yaml and values.yaml to version: ${APP_VERSION}"
echo ""
echo -e "${YELLOW}Note: Production (values-prod.yaml) should be updated manually${NC}"
echo -e "${YELLOW}      with specific version: ${APP_VERSION}${NC}"
echo -e "${YELLOW}      This ensures production deployments are intentional and reviewed.${NC}"
echo ""

# Stage 5: Git Commit and Push
echo -e "${BLUE}========== Stage 5: Git Commit & Push ==========${NC}"
git add values-dev.yaml values.yaml

if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "update demo-app image [skip ci]

    update demo-app image to ${APP_VERSION}
    "
    echo "✅ Changes committed"

    if [ "$SKIP_PUSH" = true ]; then
        echo -e "${YELLOW}⚠️  Skipping git push (--skip-push flag)${NC}"
        echo "Run 'git push origin main' manually when ready."
    else
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


# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build Complete! ✅${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Image: ${APP_NAME}:${APP_VERSION}"
echo "Commit: ${GIT_COMMIT_SHORT}"
echo "Tags: ${APP_VERSION}, latest, ${GIT_COMMIT_SHORT}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. ArgoCD will automatically detect the manifest changes and sync"
echo "   Check ArgoCD UI: kubectl port-forward -n argocd svc/argocd-server 8081:443 &"
echo "   URL: https://localhost:8081"
echo ""
echo "2. Monitor deployment status:"
echo "   kubectl get pods -n demo-app-dev"
echo "   kubectl get pods -n demo-app-staging"
echo ""
echo "3. Test the application:"
echo "   kubectl port-forward -n demo-app-dev svc/demo-app-dev 8082:80 &"
echo "   curl http://localhost:8082/health"
echo ""
echo -e "${YELLOW}Production Deployment:${NC}"
echo "  1. Edit demo-app/helm-chart/demo-app/values-prod.yaml"
echo "  2. Change image.tag to \"${APP_VERSION}\""
echo "  3. Commit and push changes"
echo "  4. ArgoCD will sync production automatically (or manually sync in UI)"
echo ""

# Made with Bob
