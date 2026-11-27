#!/usr/bin/env bash
# bootstrap.sh — recree l'arborescence complete du stack media a partir du repo.
#
# Usage :
#   cp .env.sample .env     # puis editer .env (VPN, IP, TZ)
#   ./bootstrap.sh
#   docker compose up -d
#
# Idempotent : ne supprime rien, ne fait que creer ce qui manque.

set -euo pipefail

cd "$(dirname "$0")"

echo "==> Verification de .env"
if [ ! -f .env ]; then
    echo "    .env absent -> copie de .env.sample"
    cp .env.sample .env
    echo "    !! Edite .env maintenant (NORDVPN_USER, NORDVPN_PASS, HOST_IP, TZ)"
    exit 1
fi

# Charge HOST_IP pour templater homer
set -a
# shellcheck disable=SC1091
source .env
set +a
HOST_IP="${HOST_IP:-192.168.1.100}"

echo "==> Creation des dossiers"
mkdir -p config/{qbittorrent,radarr,sonarr,prowlarr,bazarr,jellyfin,homer,npm/{data,letsencrypt},diun/data,seerr}
mkdir -p data/torrents data/media
mkdir -p vpn

echo "==> Application des templates de config"

# Homer — remplace __HOST_IP__
if [ ! -f config/homer/config.yml ]; then
    sed "s/__HOST_IP__/${HOST_IP}/g" config-templates/homer/config.yml > config/homer/config.yml
    echo "    homer/config.yml cree (IP ${HOST_IP})"
else
    echo "    homer/config.yml deja present, conserve"
fi

# Diun
if [ ! -f config/diun/diun.yml ]; then
    cp config-templates/diun/diun.yml config/diun/diun.yml
    echo "    diun/diun.yml cree"
else
    echo "    diun/diun.yml deja present, conserve"
fi

# Seerr — le dossier de config est monte sur /app/config
# Seerr tourne en UID 1000 (user node) : permissions obligatoires
if [ -d config/seerr ]; then
    chown -R "${PUID:-1000}:${PGID:-1000}" config/seerr 2>/dev/null \
        || echo "    (chown ignore : lance avec sudo si Seerr ne demarre pas)"
fi

echo "==> Verification des fichiers VPN"
if ! ls vpn/*.ovpn >/dev/null 2>&1; then
    echo "    !! Aucun .ovpn dans vpn/ — qBittorrent ne demarrera pas"
    echo "       Telecharge le tien : my.nordaccount.com -> Security -> NordVPN -> Manual Setup -> OpenVPN"
fi

echo ""
echo "Pret. Etapes suivantes :"
echo "  1. docker compose up -d"
echo "  2. docker compose ps              # tout doit passer healthy"
echo "  3. Configurer les services : voir SETUP.md sections 6-9"
echo "     - Radarr/Sonarr : ajouter qBittorrent comme client de telechargement"
echo "     - Bazarr        : activer les providers subf2m + subtitlecat (voir SETUP.md)"
echo "     - Seerr         : se connecter via 'Sign in with Jellyfin'"
