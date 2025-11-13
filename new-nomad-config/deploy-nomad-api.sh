#!/usr/bin/env bash
set -e

API_DIR="/home/omkumar.patel/nomad-deployment-api"
CONTAINER_NAME="nomad-deployment-api"
PORT=3000
SCRIPTS_DIR="/home/omkumar.patel/new-nomad-config"

echo "🚀 Deploying Nomad Deployment API..."

# Stop and remove existing container
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "🧹 Removing existing container..."
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
  docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

cd "$API_DIR"

# Build image
echo "🏗️  Building Docker image..."
docker build -t nomad-deployment-api:latest .

# Run container with restart policy
echo "🐳 Starting container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p $PORT:3000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $SCRIPTS_DIR:$SCRIPTS_DIR \
  -v /home/omkumar.patel/repos:/home/omkumar.patel/repos \
  -e PORT=3000 \
  -e SCRIPTS_DIR=$SCRIPTS_DIR \
  --network host \
  nomad-deployment-api:latest

echo "✅ Nomad Deployment API is running on port $PORT"
echo "🔗 Test: curl http://localhost:$PORT/health"

# Wait for container to be ready
sleep 3

# Add Caddy route if it doesn't exist
CADDY_API="http://127.0.0.1:2021/config/apps/http/servers/srv0/routes"
EXISTS=$(curl -s "$CADDY_API" | jq -r '.[].match[].path[]?' 2>/dev/null | grep -Fx "/api" || true)

if [ -z "$EXISTS" ]; then
  echo "🔁 Adding /api route to Nomad Caddy..."
  curl -s -X POST "$CADDY_API/0" \
       -H "Content-Type: application/json" \
       -d '{
    "match": [{"path": ["/api", "/api/*"]}],
    "handle": [{
      "handler": "reverse_proxy",
      "rewrite": {"strip_path_prefix": "/api"},
      "upstreams": [{"dial": "127.0.0.1:3000"}]
    }]
  }' > /dev/null
  echo "✅ API route added"
else
  echo "✅ /api route already exists"
fi

echo ""
echo "🎉 Deployment complete!"
echo "📡 API available at:"
echo "   - Local: http://127.0.0.1:3000/health"
echo "   - Via Caddy: http://135.235.193.224:8080/api/health"
