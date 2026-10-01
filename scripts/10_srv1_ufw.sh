#!/usr/bin/env bash
# PRIMERA PARTE - Servicio 1 (puntos 1 y 2): UFW + reenvio en el Servidor 1.
# Ejecutar en srv1:  sudo bash /vagrant/scripts/10_srv1_ufw.sh
# Deja creada la regla route del rango pasivo pero NO la del puerto 21,
# para demostrar el punto 3 (ver 11_srv1_permitir_ftp.sh).
set -euo pipefail
SRV2=192.168.50.2
PUB_IF=eth1   # interfaz de la red "publica" (192.168.56.10)

# 1) Reenvio IP: UFW lo aplica desde /etc/ufw/sysctl.conf al activarse
sed -i 's|^#\?net/ipv4/ip_forward=.*|net/ipv4/ip_forward=1|' /etc/ufw/sysctl.conf
# Politica por defecto del trafico enrutado
sed -i 's|^DEFAULT_FORWARD_POLICY=.*|DEFAULT_FORWARD_POLICY="DROP"|' /etc/default/ufw

# 2) Reglas NAT (DNAT) al inicio de /etc/ufw/before.rules
if ! grep -q '^\*nat' /etc/ufw/before.rules; then
  cp /etc/ufw/before.rules /etc/ufw/before.rules.orig
  cat > /tmp/nat.rules <<EOF
# ---------------------------------------------------------------
# Parcial 2 - Reenvio de puertos (DNAT) hacia el Servidor 2
# Todo lo que llega a la IP publica (${PUB_IF}) en estos puertos se
# reescribe con destino ${SRV2}. El filtrado lo hacen las reglas
# "ufw route" (cadena FORWARD); sin ellas el trafico se descarta.
# ---------------------------------------------------------------
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
# UFW no vacia la tabla nat al recargar: sin esto cada "ufw reload" duplica las reglas
-F PREROUTING
# FTP: canal de control
-A PREROUTING -i ${PUB_IF} -p tcp --dport 21 -j DNAT --to-destination ${SRV2}:21
# FTP: rango pasivo (canal de datos)
-A PREROUTING -i ${PUB_IF} -p tcp --dport 50000:50010 -j DNAT --to-destination ${SRV2}
# SFTP (Tercera parte): 2222 externo -> 22 del Servidor 2
#SFTP# -A PREROUTING -i ${PUB_IF} -p tcp --dport 2222 -j DNAT --to-destination ${SRV2}:22
COMMIT

EOF
  cat /tmp/nat.rules /etc/ufw/before.rules.orig > /etc/ufw/before.rules
fi

# 3) Politicas por defecto
ufw --force disable >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# 4) Solo lo estrictamente necesario
ufw allow 22/tcp comment 'Administracion SSH del Servidor 1'
ufw route allow in on ${PUB_IF} out eth2 proto tcp to ${SRV2} port 50000:50010 comment 'FTPS datos (pasivo) -> srv2'

ufw --force enable
ufw status verbose
