#!/usr/bin/env bash
set -e

BRANCH=$1
if [ -z "$BRANCH" ]; then
  echo "❌ Usage: ./deploy-nomad.sh <branch-name>"
  exit 1
fi

REPO_URL="https://github.com/omp28/app1.git"
BASE_DIR="/home/omkumar.patel/new-nomad-config"
REPO_DIR="/home/omkumar.patel/repos/app1"
JOBS_DIR="$BASE_DIR/jobs"

# Generate deterministic port (5000-6000 range for Nomad)
HASH=$(echo -n "$BRANCH" | md5sum | cut -c1-3)
PORT=$((5000 + 10#$((0x$HASH % 1000)) ))

# Set base path
if [ "$BRANCH" == "main" ]; then
  BASE_PATH="/"
else
  BASE_PATH="/$BRANCH/"
fi

echo "🚀 Deploying branch '$BRANCH' via Nomad"
echo "   Port: $PORT"
echo "   Base Path: $BASE_PATH"

# 1. Clone/Update repository
if [ ! -d "$REPO_DIR" ]; then
  echo "📦 Cloning repository..."
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
else
  echo "📦 Repository exists, updating..."
  cd "$REPO_DIR"
  git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
  git fetch origin
fi

cd "$REPO_DIR"

# Checkout branch
echo "🔄 Checking out branch '$BRANCH'..."
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" origin/"$BRANCH"
git pull origin "$BRANCH"

# 2. Build Docker image
echo "🏗️  Building Docker image..."
docker build \
  --build-arg VITE_BASE_PATH="$BASE_PATH" \
  -t "app1:$BRANCH" .

# 3. Generate Nomad job file
echo "📝 Generating Nomad job specification..."
TEMP_JOB="/tmp/nomad-app-$BRANCH.nomad"

sed -e "s/{{BRANCH}}/$BRANCH/g" \
    -e "s/{{PORT}}/$PORT/g" \
    -e "s|{{BASE_PATH}}|$BASE_PATH|g" \
    "$JOBS_DIR/app.nomad.tpl" > "$TEMP_JOB"

echo "📄 Job file: $TEMP_JOB"

# 4. Stop existing job if running
if nomad job status "app-$BRANCH" &>/dev/null; then
  echo "🛑 Stopping existing job 'app-$BRANCH'..."
  nomad job stop "app-$BRANCH" || true
  sleep 3
fi

# 5. Submit job to Nomad
echo "🚀 Submitting job to Nomad..."
nomad job run "$TEMP_JOB"

# 6. Wait for allocation
echo "⏳ Waiting for allocation to start..."
sleep 5

# 7. Check status
echo ""
echo "📊 Job Status:"
nomad job status "app-$BRANCH"

# 8. Register route in Caddy
echo ""
echo "🔧 Registering Caddy route..."
bash "$BASE_DIR/caddy/update_routes.sh" "$BRANCH" "$PORT"

echo ""
echo "✅ Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Job: app-$BRANCH"
echo "🔗 URL: http://135.235.193.224:8080/$BRANCH/"
echo "🖥️  Nomad UI: http://135.235.193.224:4646"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Useful commands:"
echo "   nomad job status app-$BRANCH"
echo "   nomad alloc logs -f \$(nomad job allocs app-$BRANCH | tail -n1 | awk '{print \$1}')"
