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
| `5055` | **Seerr** | `ghcr.io/seerr-team/seerr:latest` | Requests & discovery (successor to Jellyseerr) |
| `8888` | **Homer** | `b4bz/homer:v24.05.1` | Homelab dashboard |
| `8191` | **FlareSolverr** | `ghcr.io/flaresolverr/flaresolverr:latest` | Cloudflare bypass for Prowlarr (used by 1337x and EZTV) |

All ports are mapped `host:container` 1-to-1. Access any service from your LAN via `http://<host-ip>:<port>`.


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
- Configured for **French first, English fallback** — see [Section 9](#9-subtitles-fren-bazarr).

### Jellyfin (`jellyfin`)
- **URL:** `http://<host-ip>:8096`
- **Default login:** none — creates admin account on first-run wizard
- Streams the media library to any device on your LAN (or remotely via a reverse proxy).
- Configured with NVIDIA GPU passthrough for hardware transcoding.

### Seerr (`seerr`)
- **URL:** `http://<host-ip>:5055`
- **Default login:** none — first-run wizard, sign in with your **Jellyfin** account
- Successor to Jellyseerr/Overseerr (same project, renamed + unified). Request UI for
  movies and series; pushes approved requests into Radarr/Sonarr.
- **Migrating from Jellyseerr:** automatic — just point the volume at your old config
  folder and start the container. No manual steps. Data (users, requests, servers,
  Jellyfin link) is preserved.

> ⚠️ Seerr runs as UID **1000** (`node` user). Its config folder must be owned by
> 1000:1000 or the container crashes on boot:
> `docker run --rm -v ./config/seerr:/d alpine chown -R 1000:1000 /d`

### Homer (`homer`)
- **URL:** `http://<host-ip>:8888`
- **Default login:** none — public dashboard, no auth
- Central dashboard linking all services. Config lives at `./config/homer/config.yml`.
  `bootstrap.sh` generates it from `config-templates/homer/config.yml` with your `HOST_IP`.

### Diun (`diun`)
- No web UI — sends Discord notifications when a container image has an update.
- **Notification only** — it never pulls or restarts anything. Update manually:
  `docker compose pull && docker compose up -d`
- Config: `config/diun/diun.yml` (template in `config-templates/diun/`).
- Set `DISCORD_WEBHOOK` in `.env` **before** running `bootstrap.sh` — it writes the URL
  into `diun.yml` (permissions 600), since Diun does not expand `${VAR}` in its YAML.
- ⚠️ The `templateBody` must only reference `.Entry.*`. Using `.Manifest.Tag` makes the
  template fail to render (`can't evaluate field Manifest`) and **no notification is ever
  sent** — the scan still logs `New image found`, so the failure is easy to miss.

---

## Quick Start

```bash
git clone <this-repo> homelab && cd homelab
cp env.sample .env      # fill in NORDVPN_USER, NORDVPN_PASS, HOST_IP, TZ, LAN_NETWORK
./bootstrap.sh          # creates folders + renders config templates
docker compose up -d
```

`bootstrap.sh` is idempotent — it only creates what's missing and never overwrites
an existing config. After a couple of minutes:

```bash
docker compose ps       # everything should report (healthy)
```

Then configure each app — see `SETUP.md`:
- **Radarr/Sonarr** → add qBittorrent as download client (§6)
- **Bazarr** → enable `subf2m` + `subtitlecat`, set FR→EN profile (§9)
- **French releases** → VF quality profiles + custom formats (§10)
- **Seerr** → sign in with your Jellyfin account

### What is NOT in this repo

`.env`, `config/` and `data/` are gitignored — they hold API keys, credentials and
your media. `config-templates/` holds the versioned, sanitised versions of the
configs that can be regenerated (Homer dashboard, Diun).
