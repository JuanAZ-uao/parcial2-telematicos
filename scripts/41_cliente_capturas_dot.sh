#!/usr/bin/env bash
# Puntos 13 y 14: capturas DoT (tcp/853) vs DNS clasico (udp/53) y prueba de bloqueo del 853.
# Ejecutar en el cliente:  bash /vagrant/scripts/41_cliente_capturas_dot.sh
set -uo pipefail
S=/vagrant/scripts
DOMINIOS="example.com uao.edu.co github.com"
consultas() { for d in $DOMINIOS; do resolvectl query "$d" | head -2; done; }

echo "################ 13a) DoT ACTIVO - captura tcp.port == 853 ################"
sudo bash $S/40_cliente_dot.sh yes >/dev/null 2>&1
sudo resolvectl flush-caches
bash $S/captura.sh eth0 13a_dot_tcp853.pcap "tcp port 853 or udp port 53" "$(declare -f consultas); DOMINIOS='$DOMINIOS'; consultas"
echo "--- Paquetes UDP/53 hacia Internet durante la captura DoT (debe ser 0):"
tshark -r /vagrant/capturas/13a_dot_tcp853.pcap -Y 'udp.port==53' 2>/dev/null | wc -l
echo "--- Handshakes TLS (Client Hello con SNI) y version negociada:"
tshark -r /vagrant/capturas/13a_dot_tcp853.pcap -Y 'tls.handshake.type==1 or tls.handshake.type==2' -T fields -E separator='|' \
  -e frame.number -e ip.src -e ip.dst -e tcp.dstport -e tls.handshake.extensions_server_name -e _ws.col.Info 2>/dev/null
echo "--- Registros cifrados (Application Data) - las consultas y respuestas DNS van dentro:"
tshark -r /vagrant/capturas/13a_dot_tcp853.pcap -Y 'tls.app_data' -T fields -E separator='|' -e frame.number -e ip.src -e ip.dst -e tcp.len 2>/dev/null | head -12
echo -n "--- Nombres de dominio visibles en claro en la captura DoT: "
tshark -r /vagrant/capturas/13a_dot_tcp853.pcap -Y 'dns' 2>/dev/null | wc -l

echo
echo "################ 13b) DoT DESHABILITADO (DNSOverTLS=no) - captura udp.port == 53 ################"
sudo bash $S/40_cliente_dot.sh no >/dev/null 2>&1
resolvectl status | grep -m1 Protocols
sudo resolvectl flush-caches
bash $S/captura.sh eth0 13b_dns_udp53.pcap "udp port 53 or tcp port 853" "$(declare -f consultas); DOMINIOS='$DOMINIOS'; consultas"
echo "--- Consultas y respuestas DNS en texto plano (filtro: dns):"
tshark -r /vagrant/capturas/13b_dns_udp53.pcap -Y 'dns' -T fields -E separator='|' \
  -e frame.number -e ip.src -e ip.dst -e udp.dstport -e dns.flags.response -e dns.qry.name -e dns.qry.type -e dns.a -e dns.aaaa 2>/dev/null

echo
echo "################ 14) Firewall bloquea tcp/853: yes vs opportunistic ################"
sudo iptables -I OUTPUT -p tcp --dport 853 -j REJECT
echo "--- regla: iptables -I OUTPUT -p tcp --dport 853 -j REJECT"
for modo in yes opportunistic; do
  sudo bash $S/40_cliente_dot.sh $modo >/dev/null 2>&1
  sudo resolvectl flush-caches
  echo ">>> DNSOverTLS=$modo"
  timeout 25 resolvectl query wikipedia.org 2>&1 | head -3
done
sudo iptables -D OUTPUT -p tcp --dport 853 -j REJECT

# Estado final: DoT estricto
sudo bash $S/40_cliente_dot.sh yes >/dev/null 2>&1
echo
echo "Estado final:"; resolvectl status | grep -m1 Protocols
