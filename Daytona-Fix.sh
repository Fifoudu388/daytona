#!/bin/bash

set -uo pipefail

clear 2>/dev/null || printf "\033[2J\033[H"


echo -e "\033[1;36m"
echo " ⣏⡱ ⡀⢀ ⣀⡀ ⢀⣀ ⢀⣀ ⢀⣀ ⠄ ⣀⡀ ⢀⡀   ⡏⢱ ⢀⣀ ⡀⢀ ⣰⡀ ⢀⡀ ⣀⡀ ⢀⣀   ⡷⣸ ⢀⡀ ⣰⡀ ⡀ ⢀ ⢀⡀ ⡀⣀ ⡇⡠"
echo " ⠧⠜ ⣑⡺ ⡧⠜ ⠣⠼ ⠭⠕ ⠭⠕ ⠇ ⠇⠸ ⣑⡺   ⠧⠜ ⠣⠼ ⣑⡺ ⠘⠤ ⠣⠜ ⠇⠸ ⠣⠼   ⠇⠹ ⠣⠭ ⠘⠤ ⠱⠱⠃ ⠣⠜ ⠏  ⠏⠢"
echo ""
echo "                       Made By nafigamer"
echo -e "\033[0m"
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[1;31m[!] Run as root\033[0m"; exit 1
fi

echo -ne "\033[1;36m[ \033[0m"
colors=("\033[1;31m" "\033[1;33m" "\033[1;32m" "\033[1;36m" "\033[1;35m" "\033[1;34m")
text="Bypassing Daytona Network"
for (( i=0; i<${#text}; i++ )); do
    color=${colors[$((i % 6))]}
    echo -ne "${color}${text:$i:1}\033[0m"
    sleep 0.05
done
echo -ne "\033[1;36m ]\033[0m"

for i in {1..5}; do
    sleep 0.4
    echo -ne "\033[1;33m.\033[0m"
done
echo ""

GOST_USER="${GOST_USER:-sudo}"
GOST_PASS="${GOST_PASS:-sudo}"
GOST_HOST="${GOST_HOST:-gost-production-90a6.up.railway.app}"
GOST_PORT="${GOST_PORT:-8796}"
FULL_URL="wss://${GOST_USER}:${GOST_PASS}@${GOST_HOST}:443"

# 1) Proxy config files (profile.d + apt)
cat > /etc/profile.d/daytona-net.sh << EOF
export HTTP_PROXY=http://127.0.0.1:${GOST_PORT}
export HTTPS_PROXY=http://127.0.0.1:${GOST_PORT}
export http_proxy=http://127.0.0.1:${GOST_PORT}
export https_proxy=http://127.0.0.1:${GOST_PORT}
export NO_PROXY=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
export no_proxy=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
EOF
chmod +x /etc/profile.d/daytona-net.sh

mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99proxy << EOF
Acquire::http::Proxy "http://127.0.0.1:${GOST_PORT}";
Acquire::https::Proxy "http://127.0.0.1:${GOST_PORT}";
EOF

# 2) Source proxy vars
export HTTP_PROXY="http://127.0.0.1:${GOST_PORT}"
export HTTPS_PROXY="http://127.0.0.1:${GOST_PORT}"
export http_proxy="http://127.0.0.1:${GOST_PORT}"
export https_proxy="http://127.0.0.1:${GOST_PORT}"
export NO_PROXY="localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net"
export no_proxy="localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net"
source /etc/profile.d/daytona-net.sh

# 3) apt update/install
apt update -y &>/dev/null 2>&1 || echo -e "\033[1;31m[!] apt update failed\033[0m"
apt install -y qemu-system cloud-image-utils wget lsof curl bash &>/dev/null 2>&1 || echo -e "\033[1;31m[!] apt install failed\033[0m"

cat > /usr/local/bin/qemu-system-x86_64 << 'QWRAP'
#!/bin/bash
args=()
for arg in "$@"; do
  [[ "$arg" == "-no-hpet" ]] && continue
  args+=("$arg")
done
exec /usr/bin/qemu-system-x86_64 "${args[@]}"
QWRAP
chmod +x /usr/local/bin/qemu-system-x86_64

# 4) docker + gost (socks5)
command -v docker &>/dev/null || curl -fsSL https://get.docker.com | sh &>/dev/null 2>&1

dockerd &>/dev/null 2>&1 &
for i in $(seq 1 30); do
  docker info &>/dev/null 2>&1 && break
  sleep 1
done
docker info &>/dev/null 2>&1 || echo -e "\033[1;31m[!] dockerd not ready after 30s\033[0m"

docker rm -f gost-bridge &>/dev/null 2>&1
docker pull ginuerzh/gost:latest &>/dev/null 2>&1 || echo -e "\033[1;31m[!] docker pull ginuerzh/gost failed\033[0m"
docker run -d --net=host --restart unless-stopped \
  --name gost-bridge \
  ginuerzh/gost:latest \
  -L=socks5://:${GOST_PORT} \
  -F="$FULL_URL" &>/dev/null 2>&1 || echo -e "\033[1;31m[!] docker run gost-bridge failed\033[0m"
sleep 2

# 5) /etc/environment merge (keep existing content e.g. PATH)
touch /etc/environment
sed -i -e '/^HTTP_PROXY=/d' -e '/^HTTPS_PROXY=/d' -e '/^http_proxy=/d' -e '/^https_proxy=/d' -e '/^NO_PROXY=/d' -e '/^no_proxy=/d' /etc/environment
cat >> /etc/environment << EOF
HTTP_PROXY=http://127.0.0.1:${GOST_PORT}
HTTPS_PROXY=http://127.0.0.1:${GOST_PORT}
http_proxy=http://127.0.0.1:${GOST_PORT}
https_proxy=http://127.0.0.1:${GOST_PORT}
NO_PROXY=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
no_proxy=localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
EOF

cat > /etc/sudoers.d/proxy << 'EOFP'
Defaults env_keep += "HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy"
EOFP
chmod 440 /etc/sudoers.d/proxy
if ! visudo -cf /etc/sudoers.d/proxy &>/dev/null; then
  rm -f /etc/sudoers.d/proxy
  echo -e "\033[1;31m[!] invalid sudoers file removed\033[0m"
fi

for rc in /etc/bash.bashrc /etc/skel/.bashrc /root/.bashrc; do
    if [ -f "$rc" ]; then
        grep -q "daytona-net.sh" "$rc" 2>/dev/null || echo "source /etc/profile.d/daytona-net.sh 2>/dev/null" >> "$rc"
    fi
done

for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        grep -q "daytona-net.sh" "$user_home/.bashrc" 2>/dev/null || echo "source /etc/profile.d/daytona-net.sh 2>/dev/null" >> "$user_home/.bashrc"
        grep -q "daytona-net.sh" "$user_home/.profile" 2>/dev/null || echo "source /etc/profile.d/daytona-net.sh 2>/dev/null" >> "$user_home/.profile"
    fi
done

if [ -f /etc/zsh/zshrc ]; then
    grep -q "daytona-net.sh" /etc/zsh/zshrc 2>/dev/null || echo "source /etc/profile.d/daytona-net.sh 2>/dev/null" >> /etc/zsh/zshrc
fi

mkdir -p /etc/fish/conf.d 2>/dev/null
cat > /etc/fish/conf.d/daytona-net.fish << FISHCONF
set -gx HTTP_PROXY http://127.0.0.1:${GOST_PORT}
set -gx HTTPS_PROXY http://127.0.0.1:${GOST_PORT}
set -gx http_proxy http://127.0.0.1:${GOST_PORT}
set -gx https_proxy http://127.0.0.1:${GOST_PORT}
set -gx NO_PROXY localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
set -gx no_proxy localhost,127.0.0.1,::1,deb.debian.org,security.debian.org,snapshot.debian.org,archive.ubuntu.com,security.ubuntu.com,ppas.launchpadcontent.net
FISHCONF

if [ -f /etc/rc.local ]; then
  sed -i '/gost-bridge/d; /dockerd/d' /etc/rc.local &>/dev/null
else
  echo '#!/bin/sh' > /etc/rc.local
  chmod +x /etc/rc.local
fi
sed -i '/^exit 0/i dockerd &>/dev/null &' /etc/rc.local &>/dev/null
sed -i '/^exit 0/i docker start gost-bridge 2>/dev/null || docker run -d --net=host --restart unless-stopped --name gost-bridge ginuerzh/gost:latest -L=socks5://:'"${GOST_PORT}"' -F="'"$FULL_URL"'"' /etc/rc.local &>/dev/null

echo ""
echo -e "\033[1;36m"
echo " ⡏⢱ ⢀⣀ ⡀⢀ ⣰⡀ ⢀⡀ ⣀⡀ ⢀⣀   ⡷⣸ ⢀⡀ ⣰⡀ ⡀ ⢀ ⢀⡀ ⡀⣀ ⡇⡠   ⣏⡱ ⡀⢀ ⣀⡀ ⢀⣀ ⢀⣀ ⢀⣀ ⢀⡀ ⢀⣸"
echo " ⠧⠜ ⠣⠼ ⣑⡺ ⠘⠤ ⠣⠜ ⠇⠸ ⠣⠼   ⠇⠹ ⠣⠭ ⠘⠤ ⠱⠱⠃ ⠣⠜ ⠏  ⠏⠢   ⠧⠜ ⣑⡺ ⡧⠜ ⠣⠼ ⠭⠕ ⠭⠕ ⠣⠭ ⠣⠼"
echo -e "\033[0m"
echo ""
echo -e "\033[1;33m╔════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;33m║\033[0m  \033[1;31m⚠ If network is not working, run this command:\033[0m     \033[1;33m║\033[0m"
echo -e "\033[1;33m║\033[0m                                                        \033[1;33m║\033[0m"
echo -e "\033[1;33m║\033[0m  \033[1;36msource /etc/profile.d/daytona-net.sh\033[0m                  \033[1;33m║\033[0m"
echo -e "\033[1;33m║\033[0m                                                        \033[1;33m║\033[0m"
echo -e "\033[1;33m╚════════════════════════════════════════════════════════╝\033[0m"
echo ""