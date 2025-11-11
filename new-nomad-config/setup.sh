#!/usr/bin/env bash
set -e

echo "🔧 Setting up Nomad-based deployment system..."

# Check if Nomad is installed
if ! command -v nomad &> /dev/null; then
    echo "❌ Nomad is not installed. Installing..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install nomad
fi

# Check if Nomad is running
if ! systemctl is-active --quiet nomad; then
    echo "⚠️  Nomad is not running. Please ensure Nomad is configured and running."
    echo "   Run: sudo systemctl start nomad"
    exit 1
fi

echo "✅ Nomad is installed and running"

# Check if Caddy is running on port 8080
if sudo lsof -i :8080 &> /dev/null; then
    echo "⚠️  Port 8080 is already in use"
    echo "   Current process:"
    sudo lsof -i :8080
    read -p "   Stop existing process and start new Caddy? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pkill -f "caddy.*8080" || true
        sleep 2
    else
        echo "❌ Cannot proceed with port 8080 occupied"
        exit 1
    fi
fi

# Start Caddy for Nomad setup
echo "🚀 Starting Caddy on port 8080..."
sudo caddy run --config /home/omkumar.patel/new-nomad-config/caddy/Caddyfile --adapter caddyfile > /tmp/nomad-caddy.log 2>&1 &
CADDY_PID=$!

sleep 3

# Test Caddy
if curl -s http://127.0.0.1:8080/health | grep -q "Nomad Caddy"; then
    echo "✅ Caddy is running on port 8080"
else
    echo "❌ Failed to start Caddy"
    exit 1
fi

echo ""
echo "✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Caddy: http://135.235.193.224:8080/health"
echo "🖥️  Nomad UI: http://135.235.193.224:4646"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next steps:"
echo "   1. Deploy a branch: ./deploy-nomad.sh feature1"
echo "   2. View Nomad UI: http://135.235.193.224:4646"
echo "   3. Access app: http://135.235.193.224:8080/feature1/"
echo ""
echo "⚠️  Note: Caddy is running in background (PID: $CADDY_PID)"
echo "   To stop: sudo pkill -f 'caddy.*8080'"
