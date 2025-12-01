FROM alpine:3.22

# Install required packages
RUN apk add --no-cache \
    openvpn \
    tinyproxy \
    nginx \
    bash \
    ca-certificates \
    openssh && \
    mkdir -p /run/nginx /var/log/nginx /usr/share/nginx/html /vpn

# Runtime dirs
RUN mkdir -p /var/log/tinyproxy /run/tinyproxy /var/run/sshd

# Copy configuration and entrypoint
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# Volume:
#  - /vpn: VPN config files (.ovpn / .config / .conf)
VOLUME ["/vpn"]

# Exposed ports inside the container:
#  - 80: nginx (serves proxy.pac)
#  - 8888: tinyproxy (HTTP proxy)
#  - 22: sshd (jump host)
EXPOSE 80 8888 22

# Default environment variables
ENV VPN_CONFIG_DIR=/vpn \
    PROXY_HOSTS="" \
    TINYPROXY_PORT=8888 \
    PAC_PROXY_HOST="host.docker.internal" \
    PAC_PROXY_PORT=8888 \
    SSH_PORT=22 \
    SSH_PUBLIC_KEY_FILE="/ssh.pub"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
