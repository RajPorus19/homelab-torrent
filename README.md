# Homelab Media Stack

A self-hosted media automation stack running on Docker.
All services communicate internally over the `medianet` bridge network.
Torrent traffic is routed through NordVPN via OpenVPN.

---

## Port Map

| Port | Service | Image (pinned) | Purpose |
|------|---------|----------------|---------|
| `8080` | **qBittorrent** | `binhex/arch-qbittorrentvpn:5.1.4-2-01` | Web UI — manage downloads |
| `8118` | **Privoxy** | `binhex/arch-qbittorrentvpn:5.1.4-2-01` | HTTP proxy bundled with qBittorrentvpn (disabled by default) |
| `9696` | **Prowlarr** | `lscr.io/linuxserver/prowlarr:2.3.5.5327-ls141` | Indexer manager — syncs trackers to Radarr/Sonarr |
| `7878` | **Radarr** | `lscr.io/linuxserver/radarr:6.1.1.10360-ls298` | Movie automation — search, grab, rename |
| `8989` | **Sonarr** | `lscr.io/linuxserver/sonarr:4.0.17.2952-ls306` | TV series automation — search, grab, rename |
| `6767` | **Bazarr** | `lscr.io/linuxserver/bazarr:v1.5.6-ls342` | Automatic subtitle downloader for movies and series |
| `8096` | **Jellyfin** | `lscr.io/linuxserver/jellyfin:10.11.8ubu2404-ls27` | Media server Web UI (HTTP) |
| `8920` | **Jellyfin** | `lscr.io/linuxserver/jellyfin:10.11.8ubu2404-ls27` | Media server Web UI (HTTPS, optional) |
| `8888` | **Homer** | `b4bz/homer:v24.05.1` | Homelab dashboard |

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
- **URL:** `http://<host-ip>:8080`
- **Default login:** `admin` / check container logs on first start (`docker logs qbittorrent`) — qBittorrent 5.x generates a temporary password printed at startup
- All torrent traffic is tunnelled through NordVPN using a custom OpenVPN provider.
Place your `.ovpn` files in `./vpn/`. Radarr and Sonarr reach qBittorrent over the internal `medianet` network, not through the host.

### Prowlarr (`prowlarr`)
- **URL:** `http://<host-ip>:9696`
- **Default login:** none — creates admin account on first-run wizard
- Central indexer manager. Add your trackers here once and Prowlarr pushes them to Radarr and Sonarr automatically.

### Radarr (`radarr`)
- **URL:** `http://<host-ip>:7878`
- **Default login:** none — creates admin account on first-run wizard
- Monitors movie RSS feeds, sends grab requests to qBittorrent via Prowlarr, and renames/moves completed downloads into the media library.

### Sonarr (`sonarr`)
- **URL:** `http://<host-ip>:8989`
- **Default login:** none — creates admin account on first-run wizard
- Same as Radarr but for TV series.

### Bazarr (`bazarr`)
- **URL:** `http://<host-ip>:6767`
- **Default login:** none — no authentication enabled by default, set one up in Settings > Security
- Watches the Radarr/Sonarr libraries and automatically downloads matching subtitles.

### Jellyfin (`jellyfin`)
- **URL:** `http://<host-ip>:8096`
- **Default login:** none — creates admin account on first-run wizard
- Streams the media library to any device on your LAN (or remotely via a reverse proxy).
Configured with NVIDIA GPU passthrough for hardware transcoding.

### Homer (`homer`)
- **URL:** `http://<host-ip>:8888`
- **Default login:** none — public dashboard, no auth
- Central dashboard linking all services. Config lives at `./config/homer/config.yml`.

---

## Quick Start

```bash
cp .env.sample .env   # fill in NORDVPN_USER, NORDVPN_PASS and adjust HOST_IP
docker compose up -d
```

Verify all containers are healthy:

```bash
docker compose ps
```
