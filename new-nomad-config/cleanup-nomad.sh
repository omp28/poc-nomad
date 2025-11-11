#!/usr/bin/env bash
set -e

BRANCH=$1
if [ -z "$BRANCH" ]; then
  echo "❌ Usage: ./cleanup-nomad.sh <branch-name>"
  exit 1
fi

JOB_NAME="app-$BRANCH"
CADDY_API="http://127.0.0.1:2021/config/apps/http/servers/srv0/routes"

echo "🧹 Cleaning up deployment for branch '$BRANCH'..."

# 1. Stop Nomad job
if nomad job status "$JOB_NAME" &>/dev/null; then
  echo "🛑 Stopping Nomad job '$JOB_NAME'..."
  nomad job stop -purge "$JOB_NAME"
  sleep 2
  echo "✅ Job stopped and purged"
else
  echo "⚠️  No Nomad job found for '$JOB_NAME'"
fi

# 2. Remove Docker image (optional, comment out if you want to keep images)
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^app1:$BRANCH$"; then
  echo "🗑️  Removing Docker image 'app1:$BRANCH'..."
  docker rmi "app1:$BRANCH" 2>/dev/null || true
  echo "✅ Image removed"
fi

# 3. Remove Caddy route
echo "🔍 Removing Caddy route for /$BRANCH..."

ROUTES=$(curl -s "$CADDY_API")
ROUTES_COUNT=$(echo "$ROUTES" | jq 'length')

for i in $(seq 0 $((ROUTES_COUNT - 1))); do
  ROUTE_PATH=$(echo "$ROUTES" | jq -r ".[$i].match[0].path[0]" 2>/dev/null || echo "")
  
  if [ "$ROUTE_PATH" == "/$BRANCH" ]; then
    curl -s -X DELETE "$CADDY_API/$i" > /dev/null
    echo "✅ Route removed at index $i"
    break
  fi
done

echo ""
echo "✨ Cleanup complete for branch '$BRANCH'!"
echo ""
echo "📊 Remaining Nomad jobs:"
nomad job status | grep "^app-" || echo "No jobs running"
