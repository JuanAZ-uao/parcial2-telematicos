#!/usr/bin/env bash
# Punto 9: activa/desactiva TLS temporalmente en vsftpd para la captura de FTP plano.
#   sudo bash /vagrant/scripts/21_srv2_tls_on_off.sh off   -> FTP sin cifrar
#   sudo bash /vagrant/scripts/21_srv2_tls_on_off.sh on    -> FTPS (configuracion final)
set -euo pipefail
case "${1:-on}" in
  off) sed -i 's/^ssl_enable=.*/ssl_enable=NO/' /etc/vsftpd.conf ;;
  on)  sed -i 's/^ssl_enable=.*/ssl_enable=YES/' /etc/vsftpd.conf ;;
esac
systemctl restart vsftpd
grep '^ssl_enable' /etc/vsftpd.conf
