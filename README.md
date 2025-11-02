# 🔒 TorProxy - Anonymous Browsing for Kali Linux

**Automatically change your MAC address and route all traffic through Tor**

Simple, lightweight, no Docker required. Built specifically for Kali Linux and Debian-based systems.

## 🚀 Quick Start (One Command)

```bash
# Clone the repo
git clone https://github.com/yourusername/TorProxy.git
cd TorProxy

# Install everything (replace eth0 with your interface)
sudo chmod +x INSTALL.sh
sudo ./INSTALL.sh eth0

# Done! Now use it:
./run.sh curl https://check.torproject.org/api/ip
```

## ✨ Features

- 🎭 **MAC Address Randomization** - Cryptographically secure using `/dev/urandom`
- 🌐 **Tor Network Routing** - All traffic anonymized through Tor
- 🔒 **DNS Privacy** - DNS queries routed through Tor (no leaks)
- ⚡ **Native Performance** - No Docker overhead
- 🛠️ **Easy to Use** - Simple wrapper script for any command

## 📋 Requirements

- Kali Linux (or any Debian-based distro)
- Root/sudo access
- Network interface to modify

## 💻 Usage

### Method 1: Using the Wrapper Script (Easiest)
```bash
./run.sh curl https://httpbin.org/ip
./run.sh wget https://example.com
./run.sh firefox
./run.sh nmap -sT target.com
```

### Method 2: Direct LD_PRELOAD
```bash
LD_PRELOAD=./torproxy/torproxy.so curl https://httpbin.org/ip
```

### Method 3: Direct SOCKS Proxy
```bash
# Using curl
curl --socks5 127.0.0.1:9050 https://httpbin.org/ip

# Using proxychains
proxychains4 firefox
```

## ✅ Verify You're Anonymous

```bash
# Check if using Tor
curl --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip

# Should return: "IsTor": true
```

## ⚙️ Configuration

### Tor Settings (`/etc/tor/torrc`)
- **SOCKS proxy**: 127.0.0.1:9050
- **DNS resolver**: 127.0.0.1:9053
- **Client-only mode** (no relay)
- Optimized for privacy

## 🔧 Management

```bash
# Start Tor
sudo systemctl start tor

# Stop Tor
sudo systemctl stop tor

# Check status
sudo systemctl status tor

# View logs
sudo journalctl -u tor -f

# Change MAC again
sudo ./macChanger/macChange eth0

# Get new Tor circuit
sudo systemctl restart tor
```

## 🐛 Troubleshooting

### Tor not working?
```bash
# Check if Tor is running
nc -z 127.0.0.1 9050

# Check logs
sudo journalctl -u tor -n 50

# Restart Tor
sudo systemctl restart tor
```

### MAC change failed?
```bash
# Check interface name
ip link show

# Try manually
sudo ip link set eth0 down
sudo ./macChanger/macChange eth0
sudo ip link set eth0 up
```

## 🔐 Security Notes

- ✅ MAC address randomized with cryptographic randomness
- ✅ All TCP connections routed through Tor
- ✅ DNS queries go through Tor (prevents DNS leaks)
- ⚠️ Some apps may bypass LD_PRELOAD (use proxychains for those)
- ⚠️ UDP traffic is NOT routed through Tor
- ⚠️ Requires root for MAC changing

## 📁 Project Structure

```
TorProxy/
├── macChanger/          # MAC address randomizer
│   ├── macChange.c      # C source
│   └── Makefile
├── torproxy/            # Tor proxy library
│   ├── torproxylib.c    # SOCKS4 implementation
│   ├── torproxy.h       # Header
│   └── Makefile
├── INSTALL.sh           # One-command installer
├── run.sh               # Wrapper script
├── torrc                # Tor configuration
└── README.md            # This file
```

## 🤝 Contributing

Pull requests welcome! Please test on Kali Linux before submitting.

## ⭐ Show Your Support

If this helped you, give it a star! ⭐

## ⚖️ License

**Educational and research purposes only.** Use responsibly and in accordance with local laws.

---

**Made with ❤️ for privacy enthusiasts**
