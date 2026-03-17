#!/bin/bash

if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker daemon is not running. Please start Docker first."
    exit 1
fi

echo "================================================="
echo "      Docker OpenClaw Killer Initiated           "
echo "================================================="
echo " "

echo ">>> Step 1: Scanning for OpenClaw containers..."
C_IDS=$(docker ps -a --filter "name=openclaw" -q)
if [ -n "$C_IDS" ]; then
    echo "    Found containers. Forcing removal..."
    echo "$C_IDS" | xargs docker rm -f
else
    echo "    No containers found. Skipping."
fi

echo ">>> Step 2: Scanning for OpenClaw images..."
I_IDS=$(docker images --filter "reference=*openclaw*" -q)
if [ -n "$I_IDS" ]; then
    echo "    Found images. Forcing removal..."
    echo "$I_IDS" | xargs docker rmi -f
else
    echo "    No images found. Skipping."
fi

echo ">>> Step 3: Scanning for OpenClaw volumes..."
V_IDS=$(docker volume ls --filter "name=openclaw" -q)
if [ -n "$V_IDS" ]; then
    echo "    Found volumes. Forcing removal..."
    echo "$V_IDS" | xargs docker volume rm -f 2>/dev/null || echo "$V_IDS" | xargs docker volume rm
else
    echo "    No volumes found. Skipping."
fi

echo ">>> Step 4: Pruning OpenClaw networks..."
N_IDS=$(docker network ls --filter "name=openclaw" -q)
if [ -n "$N_IDS" ]; then
    echo "    Found networks. Forcing removal..."
    echo "$N_IDS" | xargs docker network rm 2>/dev/null
else
    echo "    No networks found. Skipping."
fi

echo ">>> Step 5: Removing local mapping directory (~/openclaw)..."
if [ -d "$HOME/openclaw" ]; then
    rm -rf "$HOME/openclaw"
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
docker ps -a --filter "name=openclaw"

echo ">>> Checking images:"
docker images --filter "reference=*openclaw*"

echo ">>> Checking volumes:"
docker volume ls --filter "name=openclaw"

echo ">>> Checking networks:"
docker network ls --filter "name=openclaw"

echo ">>> Checking local directory:"
ls -ld "$HOME/openclaw" 2>/dev/null || true

echo " "
echo "================================================="
echo "    Process Completed. Initiating self-destruct. "
echo "================================================="

if [ -f "$0" ] && [ "$0" != "bash" ] && [ "$0" != "-c" ]; then
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    DIR_NAME=$(basename "$SCRIPT_DIR")

    if [ "$DIR_NAME" = "docker-openclaw-killer" ]; then
        cd "$SCRIPT_DIR/.." || exit
        rm -rf "$SCRIPT_DIR"
    else
        rm -f "$0"
    fi
fi
