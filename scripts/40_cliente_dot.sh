#!/usr/bin/env bash
# SEGUNDA PARTE (punto 10): DNS sobre TLS con systemd-resolved en el cliente.
#   sudo bash /vagrant/scripts/40_cliente_dot.sh        -> DNSOverTLS=yes (final)
#   sudo bash /vagrant/scripts/40_cliente_dot.sh no     -> DNSOverTLS=no  (captura UDP/53)
#   sudo bash /vagrant/scripts/40_cliente_dot.sh opportunistic
set -euo pipefail
MODO="${1:-yes}"

# El DNS que entrega el DHCP de VirtualBox (10.0.2.3) se configura por interfaz
# y no soporta DoT; se ignora para que solo se usen los resolvers de resolved.conf.
if [ ! -f /etc/netplan/70-sin-dns-dhcp.yaml ]; then
  cat > /etc/netplan/70-sin-dns-dhcp.yaml <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        use-dns: false
      dhcp6-overrides:
        use-dns: false
EOF
  chmod 600 /etc/netplan/70-sin-dns-dhcp.yaml
  # Refuerzo en systemd-networkd: sin DNS por interfaz (DHCPv4 ni anuncios IPv6).
  # En la box de bento eth0 la gestiona 10-netplan-enp0s3.network (cloud-init).
  for n in 10-netplan-eth0 10-netplan-enp0s3; do
    mkdir -p /etc/systemd/network/$n.network.d
    cat > /etc/systemd/network/$n.network.d/sin-dns.conf <<'EOF'
[Network]
DNS=
[DHCPv4]
UseDNS=false
[IPv6AcceptRA]
UseDNS=false
EOF
  done
  netplan apply
  systemctl restart systemd-networkd
  networkctl reconfigure eth0
  sleep 5
fi

[ -f /etc/systemd/resolved.conf.orig ] || cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.orig
install -m 644 /vagrant/config/cliente/resolved.conf /etc/systemd/resolved.conf
sed -i "s/^DNSOverTLS=.*/DNSOverTLS=${MODO}/" /etc/systemd/resolved.conf

# /etc/resolv.conf debe apuntar al stub 127.0.0.53
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl restart systemd-resolved
resolvectl flush-caches

ls -l /etc/resolv.conf
grep -v '^#' /etc/resolv.conf | grep -v '^$'
grep -E '^(DNS|FallbackDNS|Domains|DNSOverTLS)=' /etc/systemd/resolved.conf
