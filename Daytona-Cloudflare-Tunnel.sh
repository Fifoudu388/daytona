#!/bin/bash

R="\033[1;31m"; G="\033[1;32m"; Y="\033[1;33m"; C="\033[1;36m"; W="\033[1;37m"; N="\033[0m"

clear 2>/dev/null || printf "\033[2J\033[H"

echo -e "${C}Cloudflare Tunnel via gost proxy${N}"

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${R}[!] Run as root${N}"; exit 1
fi

PROXY="127.0.0.1:8796"

echo -e "${C}[*] Checking local gost proxy on ${PROXY}${N}"
if ! (exec 3<>/dev/tcp/127.0.0.1/8796) 2>/dev/null; then
  echo -e "${Y}[!] Proxy not running - execute Daytona-Fix.sh first${N}"
  exit 1
fi
echo -e "  ${G}✓${N} proxy reachable"

echo -e "${C}[*] Installing proxychains${N}"
apt install -y proxychains4 &>/dev/null || apt install -y proxychains &>/dev/null

PC="$(command -v proxychains4 || command -v proxychains)"
if [ -z "$PC" ]; then
  echo -e "${R}[!] proxychains install failed${N}"; exit 1
fi
echo -e "  ${G}✓${N} $PC"

CONF="/etc/proxychains4.conf"
[ -f "$CONF" ] || CONF="/etc/proxychains.conf"
[ -f "$CONF" ] && cp "$CONF" "$CONF.bak" 2>/dev/null

cat > "$CONF" << 'EOF'
strict_chain
proxy_dns off
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
[ProxyList]
socks5 127.0.0.1 8796
EOF

echo -e "${C}[*] Starting cloudflared over proxy (http2)${N}"
echo -e "  ${W}Args: $*${N}"
exec "$PC" cloudflared tunnel --protocol http2 "$@"