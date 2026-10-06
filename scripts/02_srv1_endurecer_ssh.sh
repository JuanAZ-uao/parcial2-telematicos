#!/usr/bin/env bash
# srv1 queda con IP en la LAN real (public_network): su SSH de administracion solo
# debe aceptar llaves (Vagrant usa llave), no la contrasena por defecto de la box.
#   sudo bash /vagrant/scripts/02_srv1_endurecer_ssh.sh
set -euo pipefail
cat > /etc/ssh/sshd_config.d/00-solo-llaves.conf <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
CONF
sshd -t
systemctl restart ssh
sshd -T | grep -Ei '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin)'
