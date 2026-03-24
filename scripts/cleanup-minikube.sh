#!/bin/bash
# Minikube Cleanup Script
# Cleans up unused Docker images and containers in Minikube

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Minikube Cleanup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Set Minikube Docker environment
echo "Setting up Minikube Docker environment..."
eval $(minikube docker-env)
echo ""

# Function to display size
display_size() {
    docker system df
}

echo -e "${BLUE}========== Current Docker Usage ==========${NC}"
display_size
echo ""

# Show what will be cleaned
echo -e "${BLUE}========== Analysis ==========${NC}"
echo ""

echo "Demo-app images:"
docker images | grep demo-app || echo "No demo-app images found"
echo ""

echo "Dangling images (untagged):"
DANGLING_COUNT=$(docker images -f "dangling=true" -q | wc -l | tr -d ' ')
echo "Count: ${DANGLING_COUNT}"
if [ "$DANGLING_COUNT" -gt 0 ]; then
    docker images -f "dangling=true"
fi
echo ""

echo "Stopped containers:"
STOPPED_COUNT=$(docker ps -a -f "status=exited" -q | wc -l | tr -d ' ')
echo "Count: ${STOPPED_COUNT}"
if [ "$STOPPED_COUNT" -gt 0 ]; then
    docker ps -a -f "status=exited" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -20
fi
echo ""

# Cleanup options
echo -e "${YELLOW}========== Cleanup Options ==========${NC}"
echo ""
echo "1. Clean dangling images only (safe)"
echo "2. Clean stopped containers (safe)"
echo "3. Clean old demo-app images (keeps latest and 1.0.0)"
echo "4. Full cleanup (1 + 2 + 3)"
echo "5. Aggressive cleanup (removes all unused images and containers)"
echo "6. Cancel"
echo ""
echo -e "${YELLOW}Choose an option (1-6):${NC}"
read -r option

case $option in
    1)
        echo -e "${BLUE}Cleaning dangling images...${NC}"
        if [ "$DANGLING_COUNT" -gt 0 ]; then
            docker image prune -f
            echo -e "${GREEN}✅ Dangling images removed${NC}"
        else
            echo "No dangling images to remove"
        fi
        ;;

    2)
        echo -e "${BLUE}Cleaning stopped containers...${NC}"
        if [ "$STOPPED_COUNT" -gt 0 ]; then
            docker container prune -f
            echo -e "${GREEN}✅ Stopped containers removed${NC}"
        else
            echo "No stopped containers to remove"
        fi
        ;;

    3)
        echo -e "${BLUE}Cleaning old demo-app images...${NC}"
        echo "Keeping: demo-app:latest and demo-app:1.0.0"
        echo ""

        # Get images to delete (exclude latest and 1.0.0)
        IMAGES_TO_DELETE=$(docker images --format "{{.Repository}}:{{.Tag}}" | \
            grep "^demo-app:" | \
            grep -v ":latest$" | \
            grep -v ":1.0.0$" || true)

        if [ -n "$IMAGES_TO_DELETE" ]; then
            echo "Images to be deleted:"
            echo "$IMAGES_TO_DELETE"
            echo ""
            echo -e "${YELLOW}Proceed? (y/n)${NC}"
            read -r confirm
            if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                echo "$IMAGES_TO_DELETE" | xargs -r docker rmi -f
                echo -e "${GREEN}✅ Old demo-app images removed${NC}"
            else
                echo "Cancelled"
            fi
        else
            echo "No old demo-app images to remove"
        fi
        ;;

    4)
        echo -e "${BLUE}Full cleanup (dangling + stopped + old demo-app)...${NC}"
        echo ""

        # Dangling images
        if [ "$DANGLING_COUNT" -gt 0 ]; then
            echo "Removing dangling images..."
            docker image prune -f
        fi

        # Stopped containers
        if [ "$STOPPED_COUNT" -gt 0 ]; then
            echo "Removing stopped containers..."
            docker container prune -f
        fi

        # Old demo-app images
        IMAGES_TO_DELETE=$(docker images --format "{{.Repository}}:{{.Tag}}" | \
            grep "^demo-app:" | \
            grep -v ":latest$" | \
            grep -v ":1.0.0$" || true)

        if [ -n "$IMAGES_TO_DELETE" ]; then
            echo "Removing old demo-app images..."
            echo "$IMAGES_TO_DELETE" | xargs -r docker rmi -f
        fi

        echo -e "${GREEN}✅ Full cleanup complete${NC}"
        ;;

    5)
        echo -e "${RED}Aggressive cleanup - removes ALL unused images and containers${NC}"
        echo -e "${YELLOW}This will remove:${NC}"
        echo "  - All stopped containers"
        echo "  - All dangling images"
        echo "  - All unused images (not referenced by any container)"
        echo ""
        echo -e "${RED}WARNING: This may remove images needed by Kubernetes!${NC}"
        echo -e "${YELLOW}Proceed? (y/n)${NC}"
        read -r confirm

        if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            docker system prune -a -f
            echo -e "${GREEN}✅ Aggressive cleanup complete${NC}"
        else
            echo "Cancelled"
        fi
        ;;

    6)
        echo "Cleanup cancelled"
        exit 0
        ;;

    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}========== After Cleanup ==========${NC}"
display_size
echo ""

echo -e "${GREEN}Cleanup complete!${NC}"
echo ""
echo "Remaining demo-app images:"
docker images | grep demo-app || echo "No demo-app images"
echo ""

# Made with Bob
