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

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[TORPROXY]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    TORPROXY SETUP                           ║"
    echo "║              MAC Changer + Tor Container                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root. Please run as a regular user."
    exit 1
fi

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "docker-compose is not available. Please install docker-compose first."
    exit 1
fi

# Main execution
main() {
    print_banner
    
    print_step "1/7 - System Requirements Check"
    check_requirements
    
    print_step "2/7 - Network Interface Selection"
    select_interface
    
    print_step "3/7 - Building MAC Address Changer"
    build_mac_changer
    
    print_step "4/7 - Changing MAC Address"
    change_mac_address
    
    print_step "5/7 - Building and Starting Tor Container"
    setup_tor_container
    
    print_step "6/7 - Testing and Final Setup"
    test_setup
    
    print_step "7/7 - Setting up Shell Alias"
    setup_shell_alias
    
    show_usage_instructions
}

# Check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        print_status "Install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        print_status "Start Docker: sudo systemctl start docker"
        exit 1
    fi

    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "docker-compose is not available. Please install docker-compose first."
        print_status "Install docker-compose: https://docs.docker.com/compose/install/"
        exit 1
    fi

    # Check for required build tools
    if ! command -v gcc &> /dev/null; then
        print_error "GCC compiler is not installed. Please install build-essential."
        print_status "Install: sudo apt-get install build-essential"
        exit 1
    fi

    # Check for make
    if ! command -v make &> /dev/null; then
        print_error "Make is not installed. Please install make."
        print_status "Install: sudo apt-get install make"
        exit 1
    fi

    print_success "All system requirements met!"
}

# Select network interface
select_interface() {
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

# Build MAC address changer
build_mac_changer() {
    if [ ! -f "macChanger/macChange" ]; then
        print_status "Building MAC address changer..."
        cd macChanger
        make clean && make
        cd ..
        print_success "MAC address changer built successfully"
    else
        print_success "MAC address changer already built"
    fi
}

# Change MAC address
change_mac_address() {
    print_status "Testing MAC address changer permissions..."
    if ! sudo -n true 2>/dev/null; then
        print_warning "This script requires sudo privileges to change MAC address."
        print_status "You will be prompted for your password."
    fi

    print_status "Changing MAC address for interface: $INTERFACE"
    if sudo ./macChanger/macChange "$INTERFACE"; then
        print_success "MAC address changed successfully"
    else
        print_error "Failed to change MAC address"
        exit 1
    fi
}

# Setup Tor container
setup_tor_container() {
    print_status "Building Docker image for Tor proxy..."
    if docker-compose build --no-cache; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi

    print_status "Stopping any existing Tor proxy containers..."
    docker-compose down 2>/dev/null || true

    print_status "Starting Tor proxy container..."
    if docker-compose up -d; then
        print_success "Tor proxy container started successfully"
    else
        print_error "Failed to start Tor proxy container"
        exit 1
    fi

    print_status "Waiting for Tor proxy to initialize..."
    sleep 15
}

# Test the setup
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

    # Test with a simple curl request
    print_status "Testing anonymous connection through Tor..."
    if curl --socks5 127.0.0.1:9050 --max-time 10 -s https://httpbin.org/ip >/dev/null 2>&1; then
        print_success "Anonymous connection through Tor is working!"
    else
        print_warning "Anonymous connection test failed"
    fi
}

# Setup shell alias for easy usage
setup_shell_alias() {
    print_status "Setting up shell alias for easy usage..."
    
    # Get the absolute path to the project directory
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TORPROXY_SO_PATH="$PROJECT_DIR/torproxy/torproxy.so"
    
    # Create alias command
    ALIAS_CMD="alias torproxy='sudo LD_PRELOAD=$TORPROXY_SO_PATH'"
    
    # Check if alias already exists
    if grep -q "alias torproxy=" ~/.bashrc 2>/dev/null; then
        print_status "Updating existing torproxy alias in ~/.bashrc..."
        # Remove existing alias and add new one
        sed -i '/alias torproxy=/d' ~/.bashrc
        echo "$ALIAS_CMD" >> ~/.bashrc
    else
        print_status "Adding torproxy alias to ~/.bashrc..."
        echo "" >> ~/.bashrc
        echo "# TorProxy alias - added by setup.sh" >> ~/.bashrc
        echo "$ALIAS_CMD" >> ~/.bashrc
    fi
    
    # Also add to .zshrc if it exists
    if [ -f ~/.zshrc ]; then
        if grep -q "alias torproxy=" ~/.zshrc 2>/dev/null; then
            print_status "Updating existing torproxy alias in ~/.zshrc..."
            sed -i '/alias torproxy=/d' ~/.zshrc
            echo "$ALIAS_CMD" >> ~/.zshrc
        else
            print_status "Adding torproxy alias to ~/.zshrc..."
            echo "" >> ~/.zshrc
            echo "# TorProxy alias - added by setup.sh" >> ~/.zshrc
            echo "$ALIAS_CMD" >> ~/.zshrc
        fi
    fi
    
    # Create a temporary alias for current session
    eval "$ALIAS_CMD"
    
    print_success "Shell alias 'torproxy' has been set up!"
    print_status "You can now use: torproxy <command>"
}

# Show usage instructions
show_usage_instructions() {
    echo
    print_success "🎉 TorProxy setup completed successfully!"
    echo
    print_header "Usage Instructions:"
    echo "=================="
    echo "1. ✅ MAC address changed for interface: $INTERFACE"
    echo "2. ✅ Tor proxy running in Docker container"
    echo "3. ✅ SOCKS proxy: 127.0.0.1:9050"
    echo "4. ✅ DNS server: 127.0.0.1:9053"
    echo "5. ✅ Shell alias 'torproxy' configured"
    echo
    print_header "Easy Usage (NEW!):"
    echo "  torproxy <command>"
    echo
    print_header "Examples:"
    echo "  torproxy curl https://httpbin.org/ip"
    echo "  torproxy wget https://example.com"
    echo "  torproxy python3 -c \"import requests; print(requests.get('https://httpbin.org/ip').text)\""
    echo "  torproxy firefox"
    echo "  torproxy chromium-browser"
    echo
    print_header "Legacy Usage (still works):"
    echo "  sudo LD_PRELOAD=./torproxy/torproxy.so <command>"
    echo
    print_header "Management Commands:"
    echo "  Stop container:    docker-compose down"
    echo "  View logs:         docker-compose logs -f"
    echo "  Restart container: docker-compose restart"
    echo "  Check status:      docker-compose ps"
    echo
    print_header "Direct SOCKS Usage:"
    echo "  curl --socks5 127.0.0.1:9050 https://httpbin.org/ip"
    echo "  wget --proxy=on --socks5-hostname=127.0.0.1:9050 https://example.com"
    echo
    print_warning "Note: You may need to restart your terminal or run 'source ~/.bashrc' to use the alias in new terminal sessions."
    echo
    print_success "Your traffic is now anonymized through the Tor network! 🔒"
}

# Run main function
main "$@"
