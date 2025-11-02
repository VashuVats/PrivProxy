#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}[TORPROXY]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              TORPROXY - NATIVE KALI SETUP                   ║"
    echo "║          MAC Changer + Tor (No Docker Required)             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    print_step "1/6 - Installing Dependencies"
    print_status "Updating package list..."
    apt-get update -qq
    
    print_status "Installing required packages..."
    apt-get install -y tor build-essential gcc make curl wget netcat-openbsd dnsutils > /dev/null 2>&1
    
    print_success "Dependencies installed!"
}

# Select network interface
select_interface() {
    print_step "2/6 - Network Interface Selection"
    
    if [ $# -eq 0 ]; then
        print_status "Available network interfaces:"
        echo
        ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' ' | while read -r iface; do
            if [[ "$iface" != "lo" ]]; then
                echo "  - $iface"
            fi
        done
        echo
        read -p "Enter the network interface to change MAC address for: " INTERFACE
    else
        INTERFACE="$1"
    fi

    # Validate interface exists
    if ! ip link show "$INTERFACE" &> /dev/null; then
        print_error "Interface '$INTERFACE' does not exist."
        exit 1
    fi

    print_success "Selected network interface: $INTERFACE"
}

# Build MAC changer
build_mac_changer() {
    print_step "3/6 - Building MAC Address Changer"
    
    cd macChanger
    if make clean && make > /dev/null 2>&1; then
        print_success "MAC address changer built successfully"
    else
        print_error "Failed to build MAC address changer"
        exit 1
    fi
    cd ..
}

# Change MAC address
change_mac_address() {
    print_step "4/6 - Changing MAC Address"
    
    print_status "Changing MAC address for interface: $INTERFACE"
    if ./macChanger/macChange "$INTERFACE"; then
        print_success "MAC address changed successfully"
    else
        print_error "Failed to change MAC address"
        exit 1
    fi
}

# Setup Tor
setup_tor() {
    print_step "5/6 - Configuring Tor"
    
    # Stop any running Tor instance
    print_status "Stopping any existing Tor service..."
    systemctl stop tor 2>/dev/null || true
    
    # Copy our custom torrc
    print_status "Installing custom Tor configuration..."
    cp torrc /etc/tor/torrc
    
    # Create log directory
    mkdir -p /var/log/tor
    chown debian-tor:debian-tor /var/log/tor
    
    # Start Tor service
    print_status "Starting Tor service..."
    systemctl start tor
    
    # Wait for Tor to initialize
    print_status "Waiting for Tor to initialize..."
    sleep 5
    
    # Check if Tor is running
    if systemctl is-active --quiet tor; then
        print_success "Tor service is running"
    else
        print_error "Tor service failed to start"
        print_status "Check logs: journalctl -u tor -n 50"
        exit 1
    fi
}

# Build torproxy library
build_torproxy() {
    print_step "6/6 - Building Tor Proxy Library"
    
    cd torproxy
    if make clean && make > /dev/null 2>&1; then
        print_success "Tor proxy library built successfully"
    else
        print_error "Failed to build Tor proxy library"
        exit 1
    fi
    cd ..
}

# Test setup
test_setup() {
    print_status "Testing Tor proxy setup..."
    
    # Test SOCKS proxy
    if nc -z 127.0.0.1 9050 2>/dev/null; then
        print_success "SOCKS proxy is running on port 9050"
    else
        print_warning "SOCKS proxy is not responding on port 9050"
    fi
    
    # Test DNS resolution
    if nslookup google.com 127.0.0.1 -port=9053 >/dev/null 2>&1; then
        print_success "DNS resolution through Tor is working"
    else
        print_warning "DNS resolution through Tor is not working"
    fi
    
    # Test with curl
    print_status "Testing anonymous connection through Tor..."
    if timeout 15 curl --socks5 127.0.0.1:9050 -s https://check.torproject.org/api/ip | grep -q "\"IsTor\":true"; then
        print_success "✓ You are connected through Tor!"
    else
        print_warning "Connection test inconclusive"
    fi
}

# Setup shell alias
setup_shell_alias() {
    print_status "Setting up shell alias..."
    
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TORPROXY_SO_PATH="$PROJECT_DIR/torproxy/torproxy.so"
    
    ALIAS_CMD="alias torproxy='LD_PRELOAD=$TORPROXY_SO_PATH'"
    
    # Add to root's bashrc
    if grep -q "alias torproxy=" /root/.bashrc 2>/dev/null; then
        sed -i '/alias torproxy=/d' /root/.bashrc
    fi
    echo "" >> /root/.bashrc
    echo "# TorProxy alias - added by setup-kali.sh" >> /root/.bashrc
    echo "$ALIAS_CMD" >> /root/.bashrc
    
    # Add to root's zshrc if it exists
    if [ -f /root/.zshrc ]; then
        if grep -q "alias torproxy=" /root/.zshrc 2>/dev/null; then
            sed -i '/alias torproxy=/d' /root/.zshrc
        fi
        echo "" >> /root/.zshrc
        echo "# TorProxy alias - added by setup-kali.sh" >> /root/.zshrc
        echo "$ALIAS_CMD" >> /root/.zshrc
    fi
    
    print_success "Shell alias configured!"
}

# Show usage instructions
show_usage() {
    echo
    print_success "🎉 TorProxy setup completed successfully!"
    echo
    print_header "Setup Summary:"
    echo "=================="
    echo "✓ MAC address changed for interface: $INTERFACE"
    echo "✓ Tor service running natively"
    echo "✓ SOCKS proxy: 127.0.0.1:9050"
    echo "✓ DNS server: 127.0.0.1:9053"
    echo "✓ Shell alias configured"
    echo
    print_header "Usage Examples:"
    echo "  # Using the alias (reload shell first: source ~/.bashrc)"
    echo "  torproxy curl https://check.torproject.org/api/ip"
    echo "  torproxy wget https://example.com"
    echo "  torproxy firefox"
    echo
    echo "  # Direct usage with LD_PRELOAD"
    echo "  LD_PRELOAD=./torproxy/torproxy.so curl https://httpbin.org/ip"
    echo
    echo "  # Using SOCKS proxy directly"
    echo "  curl --socks5 127.0.0.1:9050 https://httpbin.org/ip"
    echo "  proxychains4 curl https://httpbin.org/ip"
    echo
    print_header "Management Commands:"
    echo "  Start Tor:   systemctl start tor"
    echo "  Stop Tor:    systemctl stop tor"
    echo "  Status:      systemctl status tor"
    echo "  Logs:        journalctl -u tor -f"
    echo
    print_header "Change MAC Again:"
    echo "  sudo ./macChanger/macChange $INTERFACE"
    echo
    print_success "Your traffic is now anonymized through Tor! 🔒"
}

# Main execution
main() {
    print_banner
    check_root
    
    install_dependencies
    select_interface "$@"
    build_mac_changer
    change_mac_address
    setup_tor
    build_torproxy
    test_setup
    setup_shell_alias
    show_usage
}

main "$@"
