# daytona-network-fix

Scripts bash pour contourner les restrictions réseau (egress bloqué) des environnements de développement Daytona : tout le trafic sortant est redirigé via un proxy gost puis un tunnel Cloudflare.

## Scripts

### Daytona-Fix.sh
Script principal. Il :
1. écrit la config proxy (`/etc/profile.d/daytona-net.sh` + apt `99proxy`), la source,
2. installe les paquets requis (qemu, cloud-image-utils, wget, lsof, curl, bash),
3. démarre `dockerd` et un conteneur `gost-bridge` (proxy gost en écoute SOCKS5 sur `127.0.0.1:GOST_PORT`, forward wss vers le relais), avec vérification des codes retour,
4. fusionne les variables proxy dans `/etc/environment` (sans écraser PATH),
5. configure sudoers (validé par `visudo -cf`), rc.local et les shells (bash, zsh, fish).

### Daytona-Qemu-VPS-Fix.sh
Variante pour un environnement QEMU/VPS : le proxy pointe vers le host (`10.0.2.2:8796`) au lieu d'un gost local, et configure profile.d, `/etc/environment`, apt et sudoers.

### Daytona-Cloudflare-Tunnel.sh
Lance un tunnel Cloudflare (`cloudflared`) en le faisant passer par le proxy local via un proxy transparent `redsocks` + iptables (le port 7844 est redirigé vers redsocks, qui s'appuie sur le SOCKS5 local). Mode foreground (défaut), `--bg` (arrière-plan) ou `stop`.

## Utilisation

Sur la machine Daytona (en root) :

```bash
# 1) Bridge réseau (gost)
./Daytona-Fix.sh

# 2) Tunnel Cloudflare (devant exécuter avec ton token)
./Daytona-Cloudflare-Tunnel.sh run --token <TOKEN>
# en arrière-plan :
./Daytona-Cloudflare-Tunnel.sh --bg run --token <TOKEN>
# arrêt :
./Daytona-Cloudflare-Tunnel.sh stop
```

Variante QEMU/VPS :

```bash
./Daytona-Qemu-VPS-Fix.sh
```

## Variables d'environnement

| Variable      | Défaut                                | Description |
|---------------|---------------------------------------|-------------|
| `GOST_USER`   | `sudo`                                | Utilisateur du relais gost (ws/wss) |
| `GOST_PASS`   | `sudo`                                | Mot de passe du relais gost |
| `GOST_HOST`   | `gost-production-90a6.up.railway.app` | Hôte du relais gost |
| `GOST_PORT`   | `8796`                                | Port d'écoute local du proxy gost |
| `REDSOCKS_PORT` | `12345`                             | Port local redsocks (transparent) |

## Avertissement

⚠️ Ce dépôt est destiné à un usage de contournement des restrictions réseau de la plateforme Daytona. Son utilisation peut violer les conditions d'utilisation de votre fournisseur. Utilisez-le uniquement sur vos propres environnements et à vos risques et périls.