# openvpn-tunnel

[![Docker Pulls](https://img.shields.io/docker/pulls/martinbuchheim/openvpn-tunnel)](https://hub.docker.com/r/martinbuchheim/openvpn-tunnel)
[![GitHub Stars](https://img.shields.io/github/stars/MartinBuchheim/openvpn-tunnel?style=social)](https://github.com/MartinBuchheim/openvpn-tunnel)
[![Build](https://github.com/MartinBuchheim/openvpn-tunnel/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/MartinBuchheim/openvpn-tunnel/actions)

**A lightweight all-in-one OpenVPN tunnel container**

![OpenVPN Tunnel](openvpn-tunnel-logo-small.png)

Includes:
- OpenVPN client  
- VPN-backed HTTP proxy (tinyproxy)  
- PAC file (via nginx) for selective routing  
- SSH jump host (ProxyJump inside the VPN)

👉 **Docker Hub:**  
https://hub.docker.com/r/martinbuchheim/openvpn-tunnel

---

## Features

- OpenVPN client with automatic config discovery  
- VPN-routed HTTP proxy  
- PAC auto-generation based on `PROXY_HOSTS`  
- SSH jump host with pubkey-only auth  
- Multi-arch (`amd64`, `arm64`)  
- Fast Alpine base image  

---

## Usage

### docker-compose (recommended)

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

---

## PAC usage

Set your browser’s auto-proxy URL:

```
http://localhost:8080/proxy.pac
```

Domains in `PROXY_HOSTS` go through the VPN proxy.

---

## SSH ProxyJump

`~/.ssh/config`:

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

Then:

```
ssh example-git
```

