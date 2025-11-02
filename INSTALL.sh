#!/bin/bash
# TorProxy - One-Command Installation for Kali Linux
# Usage: sudo ./INSTALL.sh <network-interface>
# Example: sudo ./INSTALL.sh eth0

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    TORPROXY INSTALLER                        ║
║              MAC Changer + Tor Proxy for Kali                ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Must run as root: sudo ./INSTALL.sh <interface>"
    exit 1
fi

# Get interface
if [ $# -eq 0 ]; then
    echo -e "${BLUE}[INFO]${NC} Available interfaces:"
    ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' ' | grep -v "lo"
    echo
    read -p "Enter network interface: " INTERFACE
else
    INTERFACE="$1"
fi

# Validate interface
if ! ip link show "$INTERFACE" &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Interface '$INTERFACE' not found"
    exit 1
fi

echo -e "${GREEN}[1/5]${NC} Installing dependencies..."
apt-get update -qq
apt-get install -y tor build-essential gcc make curl netcat-openbsd > /dev/null 2>&1

echo -e "${GREEN}[2/5]${NC} Building MAC changer..."
cd macChanger && make clean && make > /dev/null 2>&1 && cd ..

echo -e "${GREEN}[3/5]${NC} Building Tor proxy library..."
cd torproxy && make clean && make > /dev/null 2>&1 && cd ..

echo -e "${GREEN}[4/5]${NC} Configuring Tor..."
systemctl stop tor 2>/dev/null || true
cp torrc /etc/tor/torrc
mkdir -p /var/log/tor
chown debian-tor:debian-tor /var/log/tor
systemctl start tor
sleep 3

echo -e "${GREEN}[5/5]${NC} Changing MAC address..."
./macChanger/macChange "$INTERFACE"

# Make scripts executable
chmod +x run.sh

echo
echo -e "${GREEN}✓ Installation complete!${NC}"
echo
echo -e "${PURPLE}USAGE:${NC}"
echo "  ./run.sh curl https://check.torproject.org/api/ip"
echo "  ./run.sh firefox"
echo
echo -e "${YELLOW}TIP:${NC} Change MAC again anytime with:"
echo "  sudo ./macChanger/macChange $INTERFACE"
