# 🎬 Media Stack Setup Guide
## qBittorrent (NordVPN) + Radarr + Sonarr + Prowlarr + Bazarr + Jellyfin (NVIDIA GPU)

---

## 1. Prerequisites

### Install Docker + NVIDIA Container Toolkit

```bash
# Docker (if not already installed)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# NVIDIA Container Toolkit (required for Jellyfin GPU access)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify GPU is accessible
docker run --rm --runtime=nvidia --gpus all nvidia/cuda:12.0-base nvidia-smi
```

---

## 2. Project Structure

Clone or copy these files into a folder, e.g. `~/mediastack/`:

```
mediastack/
├── docker-compose.yml
├── .env                    ← your credentials & settings
├── vpn/                    ← put your NordVPN .ovpn files here
├── config/
│   ├── qbittorrent/
│   ├── radarr/
│   ├── sonarr/
│   ├── prowlarr/
│   ├── jellyfin/
│   └── bazarr/
└── data/
    ├── torrents/
    │   ├── movies/
    │   └── tv/
    └── media/
        ├── movies/
        └── tv/
```

Create it all at once:
```bash
mkdir -p config/{qbittorrent,radarr,sonarr,prowlarr,jellyfin,bazarr}
mkdir -p data/{torrents/{movies,tv},media/{movies,tv}}
mkdir -p vpn
```

### Split-host layout (qBittorrent on another machine)

If qBittorrent runs on a **different host** than the *arr apps, do not use a
local `./data` bind. Both `/data/torrents` and `/data/media` must live on the
**same filesystem** so Radarr/Sonarr can hardlink instead of copy.

On the download host (example: `rainbowdash`):
```bash
# torrents and media as siblings under one exported root
mkdir -p ~/qbittorrent/data/{torrents,media}
echo "$HOME/qbittorrent/data /data none bind 0 0" | sudo tee -a /etc/fstab
sudo mount --bind ~/qbittorrent/data /data
echo '/data 192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,fsid=0,insecure)' \
  | sudo tee /etc/exports
sudo exportfs -rav && sudo sv restart nfs-server
```

On the *arr host, mount it as `/data` and add an fstab entry:
```
192.168.1.104:/data /data nfs vers=3,rsize=524288,wsize=524288,hard,nolock,_netdev,auto 0 0
```

Then the compose volumes point at the absolute path (`- /data:/data`) rather
than `./data:/data`. Verify hardlinks after the first import — every file
should report `links=2`:
```bash
find /data/media -name '*.mkv' -exec stat -c '%h' {} \; | sort | uniq -c
```
Use NFS **v3** for the mount: NFSv4 on a client without `rpc.idmapd` fails with
`mount.nfs: failed to apply fstab options`.


---

## 3. NordVPN OpenVPN Setup

1. Go to https://my.nordaccount.com → **Security** → **NordVPN** → **Manual Setup** → **OpenVPN**
2. Download the `.ovpn` config for a server you want (e.g. `fr123.nordvpn.com.udp.ovpn`)
3. Place it in the `vpn/` folder:
   ```bash
   cp ~/Downloads/fr123.nordvpn.com.udp.ovpn ./vpn/
   ```
4. Edit `.env` and fill in your NordVPN email + password.

> 💡 You can put multiple `.ovpn` files in `vpn/` — the container will use whichever it finds.
> Pick a **UDP** server for better performance, or **TCP** if UDP is blocked.

---

## 4. Configure `.env`

```bash
# Find your PUID and PGID
id $USER
# Example output: uid=1000(zoomer) gid=1000(zoomer) ...

# Then fill .env:
PUID=1000
PGID=1000
TZ=Europe/Paris
NORDVPN_USER=your@nordvpn-email.com
NORDVPN_PASS=yourpassword
```

> ⚠️ Also update `LAN_NETWORK` in `docker-compose.yml` to match your local subnet.
> Run `ip route | grep default` to find it (usually `192.168.1.0/24`).

---

## 5. Start the Stack

```bash
cd ~/mediastack
docker compose up -d

# Check logs (especially qbittorrent VPN init)
docker logs -f qbittorrent
```

Wait for qBittorrent to log `Privoxy is not enabled` or `Connected to VPN` before continuing.

---

## 6. First-Time App Configuration

### qBittorrent — http://localhost:8080
- Default login: `admin` / `adminadmin`
- Go to **Tools → Options → Downloads**:
  - Default save path: `/data/torrents`
  - Enable "Create subfolder for multi-file torrents"
- **Tools → Options → WebUI**: change the password immediately

### Prowlarr — http://localhost:9696
- Go to **Settings → Indexers** → add your torrent indexers (e.g. 1337x, YTS, RARBG mirrors)
- Go to **Settings → Apps** → Add **Radarr** and **Sonarr**:
  - Server: `http://radarr:7878` and `http://sonarr:8989`
  - Get the API keys from each app under **Settings → General**

### Radarr — http://localhost:7878
- **Settings → Media Management**:
  - Root folder: `/data/media/movies`
  - Enable "Rename Movies"
- **Settings → Download Clients** → Add qBittorrent:
  - Host: `qbittorrent` (container name — Docker DNS)
  - Port: `8080`
  - Category: `movies`

### Sonarr — http://localhost:8989
- **Settings → Media Management**:
  - Root folder: `/data/media/tv`
- **Settings → Download Clients** → Add qBittorrent:
  - Host: `qbittorrent`
  - Port: `8080`
  - Category: `tv`

### Bazarr — http://localhost:6767
- **Settings → Sonarr**: point to `http://sonarr:8989`
- **Settings → Radarr**: point to `http://radarr:7878`
- Add subtitle providers (OpenSubtitles, Subscene, etc.)

### Jellyfin — http://localhost:8096
- Follow the setup wizard
- Add libraries pointing to `/data/media/movies` and `/data/media/tv`
- **Dashboard → Playback → Transcoding**:
  - Hardware acceleration: **NVENC**
  - Enable all the hardware decode/encode checkboxes

---

## 7. Verify VPN is Working

```bash
# Should show a NordVPN IP, not your real one
docker exec qbittorrent curl -s https://ipinfo.io
```

---

## 8. Useful Commands

```bash
# Start everything
docker compose up -d

# Stop everything
docker compose down

# View logs for a specific service
docker logs -f radarr

# Update all images
docker compose pull && docker compose up -d

# Restart one service
docker compose restart sonarr

# Health of everything
docker compose ps
```

---

## 9. Subtitles (FR/EN) — Bazarr

Bazarr is wired to Radarr + Sonarr but ships with **no providers enabled**, so it
does nothing until configured. Target: **French first, English fallback**.

### 9.1 Enable the free providers (no account needed)

Edit `config/bazarr/config/config.yaml` — the settings API silently drops this
list, so the file is the only reliable path:

```yaml
general:
  enabled_providers:
  - subf2m
  - subtitlecat
```

Then restart: `docker compose restart bazarr`.

### 9.2 ⚠️ subf2m self-throttles for 12h without a User-Agent

Log signature:
```
Throttling subf2m for 12 hours, because of:
ConfigurationError. Exception info: "'User-agent config missing'"
```

Fix in the same file:
```yaml
subf2m:
  user_agent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
  verify_ssl: true
```

### 9.3 ⚠️ The throttle survives a restart

It lives in a file, **not** in the DB: `config/bazarr/config/throttled_providers.dat`.
Delete it after fixing the cause, or subf2m stays dead for the full 12 hours
even though the config is now correct.

```bash
rm -f config/bazarr/config/throttled_providers.dat
docker compose restart bazarr
```

### 9.4 Language profile: French then English

`table_languages_profiles.items` is a JSON string in `config/bazarr/db/bazarr.db`.
Update profile **1** in place so every existing item picks it up:

```python
items = [
 {"id":1,"language":"fr","audio_exclude":"False","audio_only_include":"False","hi":"False","forced":"False"},
 {"id":2,"language":"en","audio_exclude":"False","audio_only_include":"False","hi":"False","forced":"False"},
]
UPDATE table_languages_profiles SET name='French then English', tag='french-english',
  items=?, cutoff=NULL, mustContain='[]', mustNotContain='[]' WHERE profileId=1
```

Back up `bazarr.db` first, stop Bazarr before writing, restart after.
**Order matters** — first item is the preferred language.

### 9.5 Verify it actually works

`GET /api/movies` returns `missing_subtitles: []` even when FR is absent — it is
**not** a reliable health signal. Do a real provider search instead:

```
GET /api/providers/movies?radarrid=<radarrId>&language=fr&hi=False&forced=False&original_format=False
```

Params are **lowercase** (`radarrid`), and `hi`/`forced`/`original_format` are
required or you get a 400. `radarrid` is the **Radarr** id, not Bazarr's row id.
The endpoint returns all languages — filter client-side on `s['language']=='fr'`.

Expected working output: `{'en': 30, 'fr': 5}` from providers `subf2m` + `subtitlecat`.

> For wider FR coverage, add an **OpenSubtitles.com** account (biggest FR
> catalogue) in Settings → Providers. Requires registration.

---

## 10. French releases (VF) — quality profiles

Radarr has **no language profiles** (`/api/v3/languageprofile` → 404), unlike
Sonarr. So "pick FR or EN at request time" is done with **quality profiles that
enforce French** via custom formats. Two extra profiles are created in both apps:

| Profile | id | Qualities | Upgrade | Cutoff |
|---|---|---|---|---|
| `4K préféré - 1080p fallback` | 7 | 1080p + 2160p | yes | Remux-2160p |
| **`4K VF - 1080p VF fallback`** | 8 | 1080p + 2160p | yes | Remux-2160p |
| **`1080p VF`** | 9 | 1080p only | no | Bluray-1080p |

### 10.1 Custom formats that gate on language

| Custom format | Score |
|---|---|
| `VFQ (Quebec French)` | +60 |
| `VFF (French France)` | +60 |
| `TRUEFRENCH` | +50 |
| `VF (French)` | +40 |
| `MULTI (French likely)` | +15 |
| `Not French (penalty)` | **−100** |

An English-only release scores −100 and is rejected. A VFF/VFQ release scores +60
and wins. Set `minCustomFormatScore: 1` on the profile so at least one French
format must match.

### 10.2 ⚠️ Group ids differ between Radarr and Sonarr

`cutoff` is a **quality-group** id, not a `/qualitydefinition` id, and the two apps
number them differently:

| Group | Radarr | Sonarr |
|---|---|---|
| `Remux-2160p` / `Bluray-2160p Remux` | **31** | **21** |
| `Bluray-1080p` | 7 | 7 |

Using Radarr's `31` on Sonarr fails with
`Cutoff must be an allowed quality or group`. Read the ids from the app's own
profile rather than hardcoding.

### 10.3 Selecting FR in Seerr

In Seerr, the profile list is the language selector. Choose
**`4K VF - 1080p VF fallback`** to get French. A native "FR/EN dropdown" is not
possible for movies — Radarr doesn't expose language profiles.

To make VF the default for every request, set Seerr's `activeProfileId` to `8`
for Radarr/Sonarr in `config/seerr/settings.json`.

---

## 11. Service Map

| Service            | URL                        | Purpose                        |
|--------------------|----------------------------|--------------------------------|
| qBittorrent        | http://localhost:8080      | Download client (behind VPN)   |
| Prowlarr           | http://localhost:9696      | Indexer/tracker manager        |
| Radarr             | http://localhost:7878      | Movie automation               |
| Sonarr             | http://localhost:8989      | TV show automation             |
| Bazarr             | http://localhost:6767      | Subtitle automation            |
| Jellyfin           | http://localhost:8096      | Media server (NVIDIA GPU)      |
| Seerr              | http://localhost:5055      | Requests & discovery           |
| Homer              | http://localhost:8888      | Dashboard                      |
| FlareSolverr       | http://localhost:8191      | Cloudflare bypass (1337x/EZTV) |

---

## How It All Connects

```
You search for a movie in Radarr
        ↓
Radarr asks Prowlarr for torrents
        ↓
Prowlarr searches your configured indexers
        ↓
Radarr sends the torrent to qBittorrent
        ↓
qBittorrent downloads it through NordVPN
        ↓
File lands in /data/torrents/movies/
        ↓
Radarr hardlinks it to /data/media/movies/
        ↓
Bazarr fetches subtitles automatically
        ↓
Jellyfin serves it with GPU transcoding
```
