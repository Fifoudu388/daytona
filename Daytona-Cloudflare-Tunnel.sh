#!/bin/bash

R="\033[1;31m"; G="\033[1;32m"; Y="\033[1;33m"; C="\033[1;36m"; W="\033[1;37m"; N="\033[0m"

clear 2>/dev/null || printf "\033[2J\033[H"

echo -e "${C}Cloudflare Tunnel via gost proxy (redsocks)${N}"

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${R}[!] Run as root${N}"; exit 1
fi

PROXY="127.0.0.1:8796"
PROXY_IP="${PROXY%:*}"
PROXY_PORT="${PROXY##*:}"
REDSOCKS_PORT="${REDSOCKS_PORT:-12345}"

command -v iptables &>/dev/null || { echo -e "${R}[!] iptables not available${N}"; exit 1; }

echo -e "${C}[*] Checking local gost proxy on ${PROXY}${N}"
if ! (exec 3<>/dev/tcp/127.0.0.1/${PROXY_PORT}) 2>/dev/null; then
  echo -e "${Y}[!] Proxy not running - execute Daytona-Fix.sh first${N}"
  exit 1
fi
echo -e "  ${G}✓${N} proxy reachable"

echo -e "${C}[*] Installing redsocks${N}"
if ! command -v redsocks &>/dev/null; then
  apt install -y redsocks &>/dev/null
fi
if ! command -v redsocks &>/dev/null; then
  echo -e "${R}[!] redsocks install failed${N}"; exit 1
fi
echo -e "  ${G}✓${N} $(command -v redsocks)"

echo -e "${C}[*] Checking cloudflared${N}"
if ! command -v cloudflared &>/dev/null; then
  echo -e "  ${G}✓${N} installing cloudflared binary"
  if command -v wget &>/dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
  else
    curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
  fi
  chmod +x /usr/local/bin/cloudflared
fi
command -v cloudflared &>/dev/null || { echo -e "${R}[!] cloudflared install failed${N}"; exit 1; }
echo -e "  ${G}✓${N} $(command -v cloudflared)"

cat > /etc/redsocks.conf << EOF
base {
  log_debug = off;
  log_info = on;
  log = "stderr";
  daemon = on;
  redirector = iptables;
}
redsocks {
  local_ip = 0.0.0.0;
  local_port = ${REDSOCKS_PORT};
  ip = ${PROXY_IP};
  port = ${PROXY_PORT};
  type = socks5;
}
EOF

echo -e "${C}[*] Setting up iptables transparent proxy${N}"
iptables -t nat -N REDSOCKS 2>/dev/null
iptables -t nat -F REDSOCKS
iptables -t nat -D OUTPUT -p tcp --dport 7844 -j REDSOCKS 2>/dev/null

# Exclude localhost (gost proxy itself) and already-captured sockets.
iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS -p tcp --dport 7844 -j REDIRECT --to-ports ${REDSOCKS_PORT}
iptables -t nat -A OUTPUT -p tcp --dport 7844 -j REDSOCKS

pkill -x redsocks 2>/dev/null
redsocks -c /etc/redsocks.conf
sleep 1

cleanup() {
  echo -e "${N}\n${C}[*] Cleaning up iptables rules${N}"
  iptables -t nat -D OUTPUT -p tcp --dport 7844 -j REDSOCKS 2>/dev/null
  iptables -t nat -F REDSOCKS
  iptables -t nat -X REDSOCKS 2>/dev/null
  pkill -x redsocks 2>/dev/null
}
trap cleanup EXIT INT TERM

echo -e "${C}[*] Starting cloudflared over proxy (http2, transparent)${N}"
echo -e "  ${W}Args: $*${N}"
cloudflared tunnel --protocol http2 "$@"