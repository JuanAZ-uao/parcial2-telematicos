#!/usr/bin/env bash
# TERCERA PARTE (punto 16): reenvio 2222 -> 192.168.50.2:22 en el Servidor 1.
#   sudo bash /vagrant/scripts/31_srv1_sftp_reenvio.sh nat      -> activa solo el DNAT
#   sudo bash /vagrant/scripts/31_srv1_sftp_reenvio.sh permitir -> agrega la regla route
#   sudo bash /vagrant/scripts/31_srv1_sftp_reenvio.sh quitar   -> elimina la regla route
set -euo pipefail
REGLA="allow in on eth1 out eth2 proto tcp to 192.168.50.2 port 22"
case "${1:-}" in
  nat)
    sed -i 's|^#SFTP# ||' /etc/ufw/before.rules
    ufw reload
    iptables -t nat -L PREROUTING -n --line-numbers
    ;;
  permitir)
    ufw route $REGLA comment 'SFTP (2222 externo) -> srv2:22'
    ufw status numbered
    ;;
  quitar)
    ufw route delete $REGLA || true
    ufw status numbered
    ;;
  *) echo "uso: $0 nat|permitir|quitar"; exit 1 ;;
esac
