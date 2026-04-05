# Homelab Media Stack

A self-hosted media automation stack running on Docker.
All services communicate internally over the `medianet` bridge network.
Torrent traffic is routed through NordVPN via OpenVPN.

---

## Port Map

| Port | Service | Purpose |
|------|---------|---------|
| `8080` | **qBittorrent** | Web UI — manage downloads |
| `8118` | **Privoxy** | HTTP proxy bundled with qBittorrentvpn (disabled by default) |
| `9696` | **Prowlarr** | Indexer manager — syncs trackers to Radarr/Sonarr |
| `7878` | **Radarr** | Movie automation — search, grab, rename |
| `8989` | **Sonarr** | TV series automation — search, grab, rename |
| `6767` | **Bazarr** | Automatic subtitle downloader for movies and series |
| `8096` | **Jellyfin** | Media server Web UI (HTTP) |
| `8920` | **Jellyfin** | Media server Web UI (HTTPS, optional) |

All ports are mapped `host:container` 1-to-1. Access any service from your LAN via `http://<host-ip>:<port>`.

---

## Other Ports in Use on This Host (not managed by this stack)

These are already occupied — do not remap the services above to any of them.

| Port | Process | Notes |
|------|---------|-------|
| `80` | secret-hitler nginx | Public-facing web app |
| `8000` | secret-hitler backend | Bound to `127.0.0.1` only |
| `11434` | Ollama | Local LLM inference, `127.0.0.1` only |
| `631` | CUPS | Print server, localhost only |
| `1716` | KDE Connect | Device pairing |
| `53` | systemd-resolved | DNS, localhost only |

---

## Services

### qBittorrent + NordVPN (`qbittorrent`)
All torrent traffic is tunnelled through NordVPN using a custom OpenVPN provider.
Place your `.ovpn` files in `./vpn/`. Radarr and Sonarr reach qBittorrent over the internal `medianet` network, not through the host.

### Prowlarr (`prowlarr`)
Central indexer manager. Add your trackers here once and Prowlarr pushes them to Radarr and Sonarr automatically.

### Radarr (`radarr`)
Monitors movie RSS feeds, sends grab requests to qBittorrent via Prowlarr, and renames/moves completed downloads into the media library.

### Sonarr (`sonarr`)
Same as Radarr but for TV series.

### Bazarr (`bazarr`)
Watches the Radarr/Sonarr libraries and automatically downloads matching subtitles.

### Jellyfin (`jellyfin`)
Streams the media library to any device on your LAN (or remotely via a reverse proxy).
Configured with NVIDIA GPU passthrough for hardware transcoding.

---

## Quick Start

```bash
cp .env.example .env   # fill in NORDVPN_USER, NORDVPN_PASS, PUID, PGID, TZ
docker compose up -d
```

Verify all containers are healthy:

```bash
docker compose ps
```
