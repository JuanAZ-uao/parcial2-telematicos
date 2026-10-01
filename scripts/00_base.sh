#!/usr/bin/env bash
# Aprovisionamiento base (lo ejecuta Vagrant). Solo instala paquetes y red;
# la configuracion de cada punto del parcial esta en los scripts 1x/2x/3x.
set -euo pipefail
ROL="$1"
export DEBIAN_FRONTEND=noninteractive

timedatectl set-timezone America/Bogota || true
apt-get update -qq

case "$ROL" in
  srv1)
    apt-get install -y -qq ufw tcpdump netcat-openbsd >/dev/null
    ;;
  srv2)
    apt-get install -y -qq vsftpd openssh-server tcpdump openssl >/dev/null
    # Ruta de retorno hacia la red del cliente a traves del Servidor 1.
    # Sin ella las respuestas saldrian por eth0 (NAT de VirtualBox) y la
    # conexion DNAT nunca se completaria.
    cat > /etc/netplan/60-ruta-cliente.yaml <<'EOF'
network:
  version: 2
  ethernets:
    eth1:
      routes:
        - to: 192.168.56.0/24
          via: 192.168.50.3
EOF
    chmod 600 /etc/netplan/60-ruta-cliente.yaml
    netplan apply
    ;;
  cliente)
    echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections
    apt-get install -y -qq lftp curl sshpass tcpdump tshark dnsutils netcat-openbsd openssl >/dev/null
    ;;
esac
echo "Base $ROL lista: $(hostname)"
