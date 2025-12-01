#!/usr/bin/env bash
set -euo pipefail

VPN_CONFIG_DIR="${VPN_CONFIG_DIR:-/vpn}"
TINYPROXY_PORT="${TINYPROXY_PORT:-8888}"
PROXY_HOSTS="${PROXY_HOSTS:-}"
PAC_PROXY_HOST="${PAC_PROXY_HOST:-host.docker.internal}"
PAC_PROXY_PORT="${PAC_PROXY_PORT:-8888}"
SSH_PORT="${SSH_PORT:-22}"
SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-/ssh.pub}"

VPN_FILE=""
VPN_DIR=""
VPN_BASENAME=""

find_vpn_config() {
  if [ -n "${VPN_CONFIG_FILE:-}" ] && [ -f "$VPN_CONFIG_FILE" ]; then
    VPN_FILE="$VPN_CONFIG_FILE"
  else
    VPN_FILE=$(find "${VPN_CONFIG_DIR}" -maxdepth 1 -type f \
      \( -name '*.ovpn' -o -name '*.config' -o -name '*.conf' \) \
      | head -n1 || true)
  fi

  if [ -z "$VPN_FILE" ]; then
    echo "ERROR: No VPN configuration file found in ${VPN_CONFIG_DIR} (.ovpn, .config, .conf)."
    exit 1
  fi

  VPN_DIR="$(dirname "$VPN_FILE")"
  VPN_BASENAME="$(basename "$VPN_FILE")"

  echo "Using VPN configuration: ${VPN_FILE}"
  echo "VPN directory: ${VPN_DIR}"
}

generate_tinyproxy_conf() {
  cat >/etc/tinyproxy/tinyproxy.conf <<EOF
User nobody
Group nobody
Port ${TINYPROXY_PORT}
Timeout 600
LogLevel Info
PidFile "/run/tinyproxy/tinyproxy.pid"
MaxClients 100
MinSpareServers 5
MaxSpareServers 20
StartServers 10
Allow 0.0.0.0/0
DisableViaHeader Yes
EOF
}

generate_pac_file() {
  local hosts_js=""
  local trimmed=""

  IFS=',' read -r -a arr <<< "${PROXY_HOSTS}"
  for h in "${arr[@]}"; do
    trimmed="$(echo "$h" | xargs)"
    [ -z "$trimmed" ] && continue
    [ -n "$hosts_js" ] && hosts_js="${hosts_js}, "
    hosts_js="${hosts_js}\"${trimmed}\""
  done

  cat >/usr/share/nginx/html/proxy.pac <<EOF
function FindProxyForURL(url, host) {
    var vpnHosts = [ ${hosts_js} ];
    var proxy = "PROXY ${PAC_PROXY_HOST}:${PAC_PROXY_PORT}";

    for (var i = 0; i < vpnHosts.length; i++) {
        var h = vpnHosts[i];
        if (dnsDomainIs(host, h) || host === h) {
            return proxy + "; DIRECT";
        }
    }

    return "DIRECT";
}
EOF
}

setup_sshd() {
  # Generate SSH host keys if necessary
  if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
  fi

  mkdir -p /root/.ssh
  chmod 700 /root/.ssh

  if [ -f "${SSH_PUBLIC_KEY_FILE}" ]; then
    echo "Using SSH public key: ${SSH_PUBLIC_KEY_FILE}"
    cat "${SSH_PUBLIC_KEY_FILE}" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
  else
    echo "WARNING: SSH_PUBLIC_KEY_FILE not found: ${SSH_PUBLIC_KEY_FILE}"
  fi

  # Hardening
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

  # Allow forwarding for ProxyJump 
  if grep -q "^AllowTcpForwarding" /etc/ssh/sshd_config; then
    sed -i 's/^AllowTcpForwarding .*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
  else
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
  fi

  if grep -q "^PermitOpen" /etc/ssh/sshd_config; then
    sed -i 's/^PermitOpen .*/PermitOpen any/' /etc/ssh/sshd_config
  else
    echo "PermitOpen any" >> /etc/ssh/sshd_config
  fi

  # Define SSH port
  if grep -q "^Port " /etc/ssh/sshd_config; then
    sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
  else
    echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
  fi

  echo "sshd configured to listen on port ${SSH_PORT}"
}

start_openvpn() {
  echo "Starting OpenVPN inside directory: ${VPN_DIR}"

  (
    cd "${VPN_DIR}"
    exec openvpn \
      --script-security 2 \
      --up /etc/openvpn/up.sh \
      --down /etc/openvpn/down.sh \
      --config "${VPN_BASENAME}"
  ) &
}

start_tinyproxy() {
  tinyproxy -d &
}

start_sshd() {
  /usr/sbin/sshd
}

start_nginx() {
  exec nginx -g "daemon off;"
}

main() {
  find_vpn_config
  generate_tinyproxy_conf
  generate_pac_file
  setup_sshd
  start_openvpn
  start_tinyproxy
  start_sshd
  start_nginx
}

main "$@"
