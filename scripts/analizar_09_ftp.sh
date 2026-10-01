#!/usr/bin/env bash
# Punto 9: analisis con tshark de las capturas FTP plano vs FTPS
# (mismo resultado que con Wireshark en Windows usando los filtros indicados).
C=/vagrant/capturas
DEC="-d tcp.port==21,tls -d tcp.port==50000-50010,tls"

echo "=================== 09a_ftp_plano.pcap (TLS deshabilitado) ==================="
echo "--- Wireshark filtro: ftp   -> USER y PASS viajan en texto plano"
tshark -r $C/09a_ftp_plano.pcap -Y ftp -T fields -E separator='|' \
  -e frame.number -e ip.src -e ftp.request.command -e ftp.request.arg -e ftp.response.code -e ftp.response.arg 2>/dev/null
echo
echo "--- Wireshark: clic derecho > Seguir > Flujo TCP sobre el canal de datos (puerto 5000x)"
for s in $(tshark -r $C/09a_ftp_plano.pcap -Y 'tcp.port>=50000 && tcp.port<=50010 && tcp.len>0' -T fields -e tcp.stream 2>/dev/null | sort -u); do
  tshark -r $C/09a_ftp_plano.pcap -q -z follow,tcp,ascii,$s 2>/dev/null | sed -n '5,8p'
done
echo
echo "--- Conversaciones TCP (1 control al 21 + 1 de datos por transferencia)"
tshark -r $C/09a_ftp_plano.pcap -q -z conv,tcp 2>/dev/null | sed -n '5,20p'

echo
echo "=================== 09b_ftps.pcap (FTPS explicito) ==================="
echo "--- Wireshark filtro: ftp   -> solo se ve en claro el saludo y AUTH TLS; despues todo es TLS"
tshark -r $C/09b_ftps.pcap -Y 'ftp.request.command or ftp.response.code' -T fields -E separator='|' \
  -e frame.number -e ftp.request.command -e ftp.request.arg -e ftp.response.code -e ftp.response.arg 2>/dev/null \
  | grep -E '\|(220|AUTH|234)\|'
echo
echo "--- Wireshark filtro: tls.handshake.type==1 || tls.handshake.type==2 (Decode As TLS en 21 y 50000-50010)"
tshark -r $C/09b_ftps.pcap $DEC -Y 'tls.handshake.type==1 or tls.handshake.type==2' -T fields -E separator='|' \
  -e frame.number -e ip.src -e tcp.srcport -e tcp.dstport -e _ws.col.Info 2>/dev/null
echo
echo "--- Registros cifrados (tls.app_data) por puerto del servidor"
tshark -r $C/09b_ftps.pcap $DEC -Y 'tls.app_data' -T fields -e tcp.srcport -e tcp.dstport 2>/dev/null \
  | awk '{p=($1<1024||($1>=50000&&$1<=50010))?$1:$2; c[p]++} END{for(k in c) print "puerto " k ": " c[k] " paquetes con Application Data cifrado"}' | sort
echo
echo -n "--- Busqueda de la contrasena en claro en la captura FTPS: "
tshark -r $C/09b_ftps.pcap -x 2>/dev/null | grep -c 'Ftps.1005' | awk '{print $1 " coincidencias"}'
echo -n "--- Busqueda del contenido del archivo en claro en la captura FTPS: "
tshark -r $C/09b_ftps.pcap -x 2>/dev/null | grep -c 'Panesso' | awk '{print $1 " coincidencias"}'
echo
echo "--- Conversaciones TCP"
tshark -r $C/09b_ftps.pcap -q -z conv,tcp 2>/dev/null | sed -n '5,20p'
