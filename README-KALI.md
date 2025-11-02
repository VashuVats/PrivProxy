# TorProxy - Native Kali Linux Setup

Run Tor proxy with MAC address changing directly on Kali Linux - **no Docker required**.

## Quick Start

```bash
# Run the automated setup (as root)
sudo chmod +x setup-kali.sh
sudo ./setup-kali.sh

# Or specify interface directly
sudo ./setup-kali.sh eth0
```

That's it! The script will:
1. ✅ Install dependencies (tor, build tools)
2. ✅ Build MAC changer
3. ✅ Change your MAC address
4. ✅ Configure and start Tor service
5. ✅ Build the torproxy library
6. ✅ Set up shell aliases

## Usage

### Method 1: Using the Alias (Easiest)
```bash
# Reload your shell first
source ~/.bashrc

# Then use the alias
torproxy curl https://check.torproject.org/api/ip
torproxy wget https://example.com
torproxy firefox
```

### Method 2: Using the Run Script
```bash
chmod +x run.sh
./run.sh curl https://httpbin.org/ip
./run.sh firefox
```

### Method 3: Direct LD_PRELOAD
```bash
LD_PRELOAD=./torproxy/torproxy.so curl https://httpbin.org/ip
```

### Method 4: Direct SOCKS Proxy
```bash
# Using curl
curl --socks5 127.0.0.1:9050 https://httpbin.org/ip

# Using proxychains
proxychains4 curl https://httpbin.org/ip

# Configure Firefox to use SOCKS5 proxy: 127.0.0.1:9050
```

## Verify You're Using Tor

```bash
# Check if you're on Tor
curl --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip

# Should return: "IsTor": true
```

## Management Commands

```bash
# Start Tor
sudo systemctl start tor

# Stop Tor
sudo systemctl stop tor

# Check status
sudo systemctl status tor

# View logs
sudo journalctl -u tor -f

# Restart Tor (get new circuit)
sudo systemctl restart tor
```

## Change MAC Address Again

```bash
sudo ./macChanger/macChange eth0
```

## Configuration

### Tor Configuration
Located at `/etc/tor/torrc` after setup:
- **SOCKS proxy**: 127.0.0.1:9050
- **DNS resolver**: 127.0.0.1:9053
- Logs: `/var/log/tor/notices.log`

### Customize Tor Settings
Edit `/etc/tor/torrc` and restart:
```bash
sudo nano /etc/tor/torrc
sudo systemctl restart tor
```

## Troubleshooting

### Tor not starting
```bash
# Check logs
sudo journalctl -u tor -n 50

# Check if port is already in use
sudo netstat -tlnp | grep 9050

# Kill existing Tor process
sudo killall tor
sudo systemctl start tor
```

### Library not loading
```bash
# Rebuild the library
cd torproxy
make clean && make
cd ..
```

### MAC change failed
```bash
# Check interface name
ip link show

# Try manually
sudo ip link set eth0 down
sudo ./macChanger/macChange eth0
sudo ip link set eth0 up
```

### Connection not going through Tor
```bash
# Test SOCKS proxy
nc -z 127.0.0.1 9050

# Test with curl
curl --socks5 127.0.0.1:9050 https://httpbin.org/ip

# Check LD_PRELOAD is set
echo $LD_PRELOAD
```

## What Gets Installed

- **tor** - The Tor daemon
- **build-essential** - GCC compiler and build tools
- **netcat-openbsd** - Network testing
- **dnsutils** - DNS testing tools

## Files Structure

```
TorProxy/
├── setup-kali.sh          # Automated setup script
├── run.sh                 # Quick run script
├── torrc                  # Tor configuration
├── macChanger/
│   ├── macChange.c        # MAC changer source
│   └── Makefile
└── torproxy/
    ├── torproxylib.c      # SOCKS proxy library
    ├── torproxy.h         # Header file
    └── Makefile
```

## Security Notes

- 🔒 MAC address is randomized on each run
- 🔒 All traffic routes through Tor network
- 🔒 DNS queries go through Tor (prevents DNS leaks)
- 🔒 Requires root/sudo for MAC changing
- ⚠️ Some applications may bypass LD_PRELOAD (use proxychains for those)

## Advanced Usage

### Use with Proxychains
```bash
# Edit /etc/proxychains4.conf
# Add: socks5 127.0.0.1 9050

proxychains4 nmap -sT target.com
proxychains4 firefox
```

### Change Tor Circuit
```bash
# Get new identity
sudo systemctl reload tor

# Or restart completely
sudo systemctl restart tor
```

### Monitor Tor Connections
```bash
# Watch Tor logs in real-time
sudo journalctl -u tor -f

# Check current circuit
sudo tail -f /var/log/tor/notices.log
```

## Uninstall

```bash
# Stop Tor
sudo systemctl stop tor
sudo systemctl disable tor

# Remove alias from shell config
sed -i '/alias torproxy=/d' ~/.bashrc
sed -i '/alias torproxy=/d' ~/.zshrc

# Optionally remove Tor
sudo apt-get remove tor
```

## Differences from Docker Version

| Feature | Docker Version | Native Kali Version |
|---------|---------------|---------------------|
| Setup | Complex | Simple |
| Performance | Slower (container overhead) | Faster (native) |
| Resource Usage | Higher | Lower |
| Isolation | Better | Less isolated |
| Persistence | Requires container management | System service |
| Best For | Multi-platform, testing | Kali Linux, production use |

## License

Educational and research purposes. Use responsibly and in accordance with local laws.
