#!/bin/bash
# Startup script for local development with SAM and MongoDB

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GC Feedback Collection API - Local Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Clean up any orphaned SAM Lambda containers
echo -e "${YELLOW}Cleaning up orphaned SAM containers...${NC}"
ORPHANED=$(docker ps -q --filter ancestor=public.ecr.aws/lambda/python:3.11-rapid-x86_64 2>/dev/null)
if [ ! -z "$ORPHANED" ]; then
    echo "Stopping $(echo "$ORPHANED" | wc -l | tr -d ' ') orphaned container(s)..."
    echo "$ORPHANED" | xargs docker stop > /dev/null 2>&1 || true
    echo "$ORPHANED" | xargs docker rm > /dev/null 2>&1 || true
    echo -e "${GREEN}✓ Cleaned up orphaned containers${NC}"
else
    echo -e "${GREEN}✓ No orphaned containers found${NC}"
fi
echo ""

# Check for required tools
echo -e "${YELLOW}Checking for required tools...${NC}"
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: docker is required but not installed.${NC}" >&2; exit 1; }
command -v sam >/dev/null 2>&1 || { echo -e "${RED}Error: AWS SAM CLI is required but not installed.${NC}" >&2; exit 1; }
echo -e "${GREEN}✓ All required tools found${NC}"
echo ""

# Create Docker network if it doesn't exist
echo -e "${YELLOW}Setting up Docker network...${NC}"
if ! docker network inspect gc-feedback-network >/dev/null 2>&1; then
    docker network create gc-feedback-network
    echo -e "${GREEN}✓ Docker network created${NC}"
else
    echo -e "${GREEN}✓ Docker network already exists${NC}"
fi
echo ""

# Start services
echo -e "${YELLOW}Starting MongoDB and SQS (ElasticMQ)...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# Wait for MongoDB to be ready
echo -e "${YELLOW}Waiting for MongoDB to be ready...${NC}"
attempt=0
max_attempts=30
until docker exec gc-feedback-mongodb mongosh --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}Error: MongoDB failed to start after $max_attempts attempts${NC}"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""
echo -e "${GREEN}✓ MongoDB is ready${NC}"
echo ""

# Wait for ElasticMQ to be ready
echo -e "${YELLOW}Waiting for ElasticMQ (SQS) to be ready...${NC}"
attempt=0
max_attempts=30
until curl -s http://localhost:9324 > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}Error: ElasticMQ failed to start after $max_attempts attempts${NC}"
        exit 1
    fi
    echo -n "."
    sleep 1
done
echo ""
echo -e "${GREEN}✓ ElasticMQ is ready${NC}"
echo ""

# Get Docker gateway IP for Colima compatibility
echo -e "${YELLOW}Detecting Docker network gateway...${NC}"
GATEWAY_IP=$(docker network inspect gc-feedback-collection-api_gc-feedback-network | grep -o '"Gateway": "[^"]*"' | grep -o '[0-9.]*')
if [ -z "$GATEWAY_IP" ]; then
    GATEWAY_IP="172.27.0.1"
    echo -e "${YELLOW}Using default gateway: $GATEWAY_IP${NC}"
else
    echo -e "${GREEN}Gateway IP: $GATEWAY_IP${NC}"
fi
echo ""

# Build SAM application
echo -e "${YELLOW}Building SAM application...${NC}"
sam build
echo -e "${GREEN}✓ SAM build completed${NC}"
echo ""

# Display information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting SAM Local API...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}API will be available at: http://localhost:3000${NC}"
echo ""
echo -e "${YELLOW}Available endpoints:${NC}"
echo "  POST http://localhost:3000/problem/form"
echo "  POST http://localhost:3000/problem/email"
echo "  POST http://localhost:3000/toptask/survey/form"
echo "  POST http://localhost:3000/toptask/email"
echo "  POST http://localhost:3000/admin/process-problems"
echo "  POST http://localhost:3000/admin/process-toptasks"
echo ""
echo -e "${YELLOW}MongoDB:${NC}"
echo "  Host: localhost:27017"
echo "  Database: pagesuccess"
echo "  Username: admin"
echo "  Password: password"
echo ""
echo -e "${YELLOW}SQS Queues (local):${NC}"
echo "  Problem Queue: http://localhost:9324/000000000000/problem-queue"
echo "  TopTask Queue: http://localhost:9324/000000000000/toptask-queue"
echo ""
echo -e "${GREEN}Press Ctrl+C to stop the API server${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Start SAM local API
# For Colima compatibility, use --add-host to map host.docker.internal to gateway
echo -e "${YELLOW}Using gateway IP for host.docker.internal mapping: $GATEWAY_IP${NC}"
echo ""
sam local start-api --warm-containers EAGER --add-host host.docker.internal:$GATEWAY_IP

# Cleanup on exit
trap "echo 'Stopping services...'; docker-compose down" EXIT
