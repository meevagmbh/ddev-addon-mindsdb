#!/bin/bash
#ddev-generated

# Debug script for MindsDB container troubleshooting
# Usage: ./debug-mindsdb.sh [project-name]

PROJECT_NAME=${1:-$(ddev describe -j | jq -r '.name' 2>/dev/null)}
CONTAINER_NAME="ddev-${PROJECT_NAME}-mindsdb"

echo "🔍 MindsDB Debug Information for project: ${PROJECT_NAME}"
echo "========================================================"

# Check if container exists
if ! docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container ${CONTAINER_NAME} not found"
    echo "Available containers:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep ddev
    exit 1
fi

# Container status
echo "📊 Container Status:"
docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

# Health check status
echo "🩺 Health Check Status:"
docker inspect --format "{{ json .State.Health }}" "${CONTAINER_NAME}" | jq -r '.' 2>/dev/null || echo "No health check data available"
echo

# Recent container logs
echo "📝 Recent Container Logs (last 50 lines):"
echo "----------------------------------------"
docker logs --tail 50 "${CONTAINER_NAME}" 2>&1
echo

# MindsDB-specific debug info
echo "🧠 MindsDB-specific Debug Info:"
echo "------------------------------"
if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" | grep -q "${CONTAINER_NAME}"; then
    echo "✅ Container is running"

    # Check if MindsDB API is responding
    echo "🌐 API Endpoint Check:"
    if docker exec "${CONTAINER_NAME}" python -c "import urllib.request; urllib.request.urlopen('http://localhost:47334/api/util/ping')" 2>/dev/null; then
        echo "✅ MindsDB API is responding"
    else
        echo "❌ MindsDB API is not responding"
    fi

    # Check ports
    echo "🔌 Port Check:"
    docker exec "${CONTAINER_NAME}" netstat -ln 2>/dev/null | grep -E ':(47334|47335|47336)' || echo "netstat not available"

    # Check processes
    echo "⚙️  Process Check:"
    docker exec "${CONTAINER_NAME}" ps aux 2>/dev/null | grep -v grep | grep -E '(python|mindsdb)' || echo "ps not available"

else
    echo "❌ Container is not running"

    # Try to get exit code
    EXIT_CODE=$(docker inspect --format='{{.State.ExitCode}}' "${CONTAINER_NAME}" 2>/dev/null)
    echo "Exit code: ${EXIT_CODE}"
fi

# System resources
echo "💾 System Resources:"
echo "-------------------"
docker stats "${CONTAINER_NAME}" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "Container not running for stats"

# Troubleshooting suggestions
echo "🔧 Troubleshooting Commands:"
echo "----------------------------"
echo "View full logs:     docker logs ${CONTAINER_NAME}"
echo "Follow logs:        docker logs -f ${CONTAINER_NAME}"
echo "Inspect container:  docker inspect ${CONTAINER_NAME}"
echo "Execute shell:      docker exec -it ${CONTAINER_NAME} /bin/bash"
echo "Restart container:  ddev restart"
echo "Remove and rebuild: ddev stop && ddev start"