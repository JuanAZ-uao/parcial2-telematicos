#!/usr/bin/env bash
# PRIMERA PARTE - Servicio 2 (puntos 5 y 6): vsftpd en modo FTPS en el Servidor 2.
# Ejecutar en srv2:  sudo bash /vagrant/scripts/20_srv2_vsftpd.sh
set -euo pipefail
CODIGO=1005968285
FTP_USER="ftp_${CODIGO}"
FTP_PASS="Ftps.${CODIGO}"

# Certificados (genera la CA si no existe e instala en /etc/ssl/parcial2)
bash /vagrant/scripts/05_certs_srv2.sh >/dev/null

# Usuario FTP local
if ! id "$FTP_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$FTP_USER"
fi
echo "${FTP_USER}:${FTP_PASS}" | chpasswd
echo "Archivo de bienvenida del Servidor 2 (${CODIGO})" > "/home/${FTP_USER}/bienvenida.txt"
chown "${FTP_USER}:" "/home/${FTP_USER}/bienvenida.txt"
echo "$FTP_USER" > /etc/vsftpd.userlist

# Configuracion
[ -f /etc/vsftpd.conf.orig ] || cp /etc/vsftpd.conf /etc/vsftpd.conf.orig
install -m 644 /vagrant/config/srv2/vsftpd.conf /etc/vsftpd.conf
touch /var/log/vsftpd.log
systemctl restart vsftpd
sleep 2
systemctl --no-pager --lines=0 status vsftpd
ss -ltnp | grep -E ':21\s'
