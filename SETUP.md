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
```

---

## Service Map

| Service       | URL                        | Purpose                        |
|---------------|----------------------------|--------------------------------|
| qBittorrent   | http://localhost:8080      | Download client (behind VPN)   |
| Prowlarr      | http://localhost:9696      | Indexer/tracker manager        |
| Radarr        | http://localhost:7878      | Movie automation               |
| Sonarr        | http://localhost:8989      | TV show automation             |
| Bazarr        | http://localhost:6767      | Subtitle automation            |
| Jellyfin      | http://localhost:8096      | Media server (NVIDIA GPU)      |

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
