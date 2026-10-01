#!/usr/bin/env bash
# TERCERA PARTE (punto 15): usuario exclusivo SFTP enjaulado en el Servidor 2.
# Ejecutar en srv2:  sudo bash /vagrant/scripts/30_srv2_sftp.sh
set -euo pipefail
CODIGO=1005968285
U="sftp_${CODIGO}"
P="Sftp.${CODIGO}"

# Usuario sin shell interactiva util
id "$U" &>/dev/null || useradd -M -d /archivos -s /usr/sbin/nologin "$U"
echo "${U}:${P}" | chpasswd

# ChrootDirectory exige que la jaula y sus padres sean de root y no escribibles
# por otros; por eso el usuario escribe en un subdirectorio propio.
install -d -o root -g root -m 755 /srv/sftp
install -d -o root -g root -m 755 "/srv/sftp/${U}"
install -d -o "$U" -g "$U" -m 755 "/srv/sftp/${U}/archivos"
echo "Archivo de bienvenida SFTP (${CODIGO})" > "/srv/sftp/${U}/archivos/leeme.txt"
chown "$U:$U" "/srv/sftp/${U}/archivos/leeme.txt"

[ -f /etc/ssh/sshd_config.orig ] || cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
# El Subsystem se cambia a internal-sftp (no necesita binarios dentro de la jaula)
sed -i 's|^Subsystem\s\+sftp.*|Subsystem sftp internal-sftp|' /etc/ssh/sshd_config
if ! grep -q "^Match User ${U}" /etc/ssh/sshd_config; then
  cat >> /etc/ssh/sshd_config <<EOF

# --- Parcial 2: usuario exclusivo SFTP, enjaulado y sin shell ---
Match User ${U}
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp -l INFO
    PasswordAuthentication yes
    AllowTcpForwarding no
    AllowAgentForwarding no
    PermitTunnel no
    X11Forwarding no
EOF
fi
sshd -t
systemctl restart ssh
sshd -T -C user=${U},host=x,addr=192.168.56.20 | grep -Ei '^(chrootdirectory|forcecommand|passwordauthentication|allowtcpforwarding)'
