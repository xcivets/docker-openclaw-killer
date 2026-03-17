#!/bin/bash

echo "================================================="
echo "      Docker OpenClaw Killer Initiated           "
echo "================================================="
echo " "

echo ">>> Step 1: Scanning for OpenClaw containers..."
C_IDS=$(docker ps -a | grep openclaw | awk '{print $1}')
if [ -n "$C_IDS" ]; then
    echo "    Found containers. Forcing removal..."
    docker rm -f $C_IDS
else
    echo "    No containers found. Skipping."
fi

echo ">>> Step 2: Scanning for OpenClaw images..."
I_IDS=$(docker images | grep openclaw | awk '{print $3}')
if [ -n "$I_IDS" ]; then
    echo "    Found images. Forcing removal..."
    docker rmi -f $I_IDS
else
    echo "    No images found. Skipping."
fi

echo ">>> Step 3: Scanning for OpenClaw volumes..."
V_IDS=$(docker volume ls | grep openclaw | awk '{print $2}')
if [ -n "$V_IDS" ]; then
    echo "    Found volumes. Forcing removal..."
    docker volume rm $V_IDS
else
    echo "    No volumes found. Skipping."
fi

echo ">>> Step 4: Pruning unused Docker networks..."
docker network prune -f

echo ">>> Step 5: Pruning Docker system cache and dangling resources..."
docker system prune -a --volumes -f

echo ">>> Step 6: Removing local mapping directory (~/openclaw)..."
if [ -d "$HOME/openclaw" ]; then
    rm -rf ~/openclaw
    echo "    Local directory removed."
else
    echo "    Local directory not found. Skipping."
fi

echo " "
echo "================================================="
echo "      Starting Verification Phase                "
echo "================================================="
echo " "

echo ">>> Checking containers:"
docker ps -a | grep openclaw

echo ">>> Checking images:"
docker images | grep openclaw

echo ">>> Checking volumes:"
docker volume ls | grep openclaw

echo ">>> Checking networks:"
docker network ls | grep openclaw

echo ">>> Checking local directory:"
ls -ld ~/openclaw 2>/dev/null

echo " "
echo "================================================="
echo "    Process Completed. Initiating self-destruct. "
echo "================================================="

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DIR_NAME=$(basename "$SCRIPT_DIR")

if [ "$DIR_NAME" = "docker-openclaw-killer" ]; then
    cd "$SCRIPT_DIR/.." || exit
    rm -rf "$SCRIPT_DIR"
else
    rm -f "$0"
fi
