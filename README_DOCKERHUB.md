
# openvpn-tunnel

![Build](https://github.com/MartinBuchheim/openvpn-tunnel/actions/workflows/docker-publish.yml/badge.svg)
![License](https://img.shields.io/github/license/MartinBuchheim/openvpn-tunnel)
![Stars](https://img.shields.io/github/stars/MartinBuchheim/openvpn-tunnel?style=social)
![Docker Pulls](https://img.shields.io/docker/pulls/martinbuchheim/openvpn-tunnel)

**A lightweight, multi-purpose OpenVPN tunnel container.**

![OpenVPN Tunnel](https://raw.githubusercontent.com/MartinBuchheim/openvpn-tunnel/refs/heads/main/openvpn-tunnel-logo-small.png)

This image bundles:
- an **OpenVPN client**
- a **VPN-backed HTTP proxy** (tinyproxy)
- **nginx** serving a Proxy Auto-Config (PAC) file
- a built-in **SSH jump host** for ProxyJump into the VPN

It is ideal for:
- routing selected browser domains through a VPN  
- using a jump host from inside the VPN  
- integrating PAC-based selective routing + SSH + proxying in one container

## Features

- Fully automated OpenVPN client startup  
- Relative certificate paths in `.ovpn` supported (OpenVPN runs inside `/vpn`)  
- HTTP proxy routed through the VPN  
- PAC file generation based on `PROXY_HOSTS`  
- SSH jump host with pubkey auth only  
- Multi-arch images (linux/amd64 + linux/arm64)

## Volumes

### `/vpn` (required)

Contains:

```
myvpn.ovpn
cacert.pem
client_crt.pem
client_key.pem
ta.key
```

### `/ssh.pub` (required)

Mount a **single public key file**, e.g.:

```
- ~/.ssh/id_ed25519.pub:/ssh.pub:ro
```

It gets written to `/root/.ssh/authorized_keys`.

## Ports

| Container | Purpose |
|----------|---------|
| 80       | PAC file via nginx |
| 8888     | tinyproxy |
| 22       | SSH jump host |

Example mapping:

```
8080:80     → PAC
8888:8888   → HTTP Proxy
2222:22     → SSH Jump Host
```

## Environment variables

- `PROXY_HOSTS` — comma-separated list of domains (e.g. `.example.com,.corp.local`)
- `PAC_PROXY_HOST` — usually `localhost`
- `PAC_PROXY_PORT` — port used by tinyproxy on host
- `TINYPROXY_PORT` — internal tinyproxy port (default 8888)
- `SSH_PORT` — SSH port inside container (default 22)
- `SSH_PUBLIC_KEY_FILE` — path to mounted pubkey (`/ssh.pub`)

## Example docker-compose

```yaml
services:
  openvpn-tunnel:
    image: martinbuchheim/openvpn-tunnel:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun

    volumes:
      - ~/vpn-configs/example:/vpn:ro
      - ~/.ssh/id_ed25519.pub:/ssh.pub:ro

    environment:
      PROXY_HOSTS: "example.com"
      PAC_PROXY_HOST: "localhost"
      PAC_PROXY_PORT: "8888"

    ports:
      - "8080:80"
      - "8888:8888"
      - "2222:22"
```

## PAC usage

Configure in your browser:

```
http://localhost:8080/proxy.pac
```

Domains listed in `PROXY_HOSTS` route through the VPN-backed proxy.

## SSH ProxyJump usage

Example `~/.ssh/config`:

```
Host example-jump
    HostName localhost
    Port 2222
    User root

Host example-git
    HostName git.example.com
    User git
    ProxyJump example-jump    
```

Usage:

```
ssh example-git
```

## Project links

- GitHub: https://github.com/MartinBuchheim/openvpn-tunnel  
- Docker Hub: https://hub.docker.com/r/martinbuchheim/openvpn-tunnel  

