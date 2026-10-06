#!/usr/bin/env bash
# Interfaz de la public_network (puenteada a la LAN real): solo aporta una IP por DHCP.
# No debe tomar ruta por defecto ni DNS, para no alterar la topologia del parcial
# (ruta hacia 192.168.50.0/24 inexistente en el cliente) ni la demostracion de DoT.
#   sudo bash /vagrant/scripts/01_red_publica.sh <interfaz>
set -euo pipefail
IF="$1"
D="/etc/systemd/network/10-netplan-${IF}.network.d"
mkdir -p "$D"
cat > "$D/solo-ip.conf" <<'CONF'
[Network]
DNS=
[DHCPv4]
UseDNS=false
UseRoutes=false
UseGateway=false
[IPv6AcceptRA]
UseDNS=false
CONF
networkctl reload
networkctl reconfigure "$IF"
sleep 4
echo "== $IF"; ip -br -4 addr show "$IF"; echo "rutas por defecto por $IF: $(ip route show default dev "$IF" | wc -l)"
