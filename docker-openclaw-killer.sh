#!/bin/bash

echo "Starting OpenClaw Uninstallation..."

C_IDS=$(docker ps -a | grep openclaw | awk '{print $1}')
if [ -n "$C_IDS" ]; then docker rm -f $C_IDS; fi

I_IDS=$(docker images | grep openclaw | awk '{print $3}')
if [ -n "$I_IDS" ]; then docker rmi -f $I_IDS; fi

V_IDS=$(docker volume ls | grep openclaw | awk '{print $2}')
if [ -n "$V_IDS" ]; then docker volume rm $V_IDS; fi

docker network prune -f

docker system prune -a --volumes -f

rm -rf ~/openclaw

echo "Starting Verification..."

docker ps -a | grep openclaw
docker images | grep openclaw
docker volume ls | grep openclaw
docker network ls | grep openclaw
ls -ld ~/openclaw

echo "Process Completed. Initiating self-destruct..."

rm -f "$0"
