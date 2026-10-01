#!/usr/bin/env bash
# Punto 3: agrega (o quita con "quitar") la regla route del canal de control FTP.
#   sudo bash /vagrant/scripts/11_srv1_permitir_ftp.sh          -> agrega
#   sudo bash /vagrant/scripts/11_srv1_permitir_ftp.sh quitar   -> elimina
set -euo pipefail
REGLA="allow in on eth1 out eth2 proto tcp to 192.168.50.2 port 21"
if [ "${1:-}" = "quitar" ]; then
  ufw route delete $REGLA || true
else
  ufw route $REGLA comment 'FTPS control -> srv2'
fi
ufw status numbered
