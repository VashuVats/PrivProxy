#!/bin/bash
# Quick run script for TorProxy on Kali Linux

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TORPROXY_SO="$SCRIPT_DIR/torproxy/torproxy.so"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if torproxy.so exists
if [ ! -f "$TORPROXY_SO" ]; then
    echo -e "${RED}[ERROR]${NC} torproxy.so not found!"
    echo "Run: cd torproxy && make"
    exit 1
fi

# Check if Tor is running
if ! systemctl is-active --quiet tor; then
    echo -e "${YELLOW}[WARNING]${NC} Tor service is not running"
    echo "Starting Tor service..."
    sudo systemctl start tor
    sleep 3
fi

# Check if SOCKS proxy is available
if ! nc -z 127.0.0.1 9050 2>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Tor SOCKS proxy not available on port 9050"
    echo "Check Tor status: systemctl status tor"
    exit 1
fi

# Run the command with LD_PRELOAD
if [ $# -eq 0 ]; then
    echo "Usage: $0 <command> [args...]"
    echo
    echo "Examples:"
    echo "  $0 curl https://check.torproject.org/api/ip"
    echo "  $0 wget https://example.com"
    echo "  $0 firefox"
    exit 1
fi

echo -e "${GREEN}[+]${NC} Running through Tor proxy..."
export LD_PRELOAD="$TORPROXY_SO"
exec "$@"
