#!/bin/bash

# Usage:
#  Change MAC then run a command through Tor hook:
#    sudo ./torproxy.sh /path/to/torproxy.so <iface> <command> [args...]
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 /path/to/torproxy.so <iface> command [args...]" 1>&2
  exit 1
fi

SO_PATH="$1"; shift
IFACE="$1"; shift

# Change MAC (requires root)
"$(dirname "$0")"/../macChanger/macChange "$IFACE"

export LD_PRELOAD="$SO_PATH"
"$@"
unset LD_PRELOAD

