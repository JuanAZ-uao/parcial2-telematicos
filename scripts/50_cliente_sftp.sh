#!/usr/bin/env bash
# Puntos 17 y 18: conexion SFTP desde el cliente a traves del firewall (2222) y captura.
# Ejecutar en el cliente:  bash /vagrant/scripts/50_cliente_sftp.sh
# (sshpass solo se usa para automatizar la contrasena en la evidencia; en la
#  sustentacion basta con: sftp -P 2222 sftp_1005968285@192.168.56.10)
set -uo pipefail
U=sftp_1005968285; PUB=192.168.56.10
export SSHPASS=Sftp.1005968285
cd ~
echo "Archivo SFTP del parcial - Juan Esteban Panesso 1005968285 - $(date)" > 1005968285_sftp.txt
rm -f ~/.ssh/known_hosts descargado_sftp.txt

echo "################ 17) Huella de la clave de host en la primera conexion ################"
echo "--- Huella publicada por el servidor (ssh-keyscan a traves del firewall):"
ssh-keyscan -p 2222 -t ed25519 $PUB 2>/dev/null | ssh-keygen -lf -
echo "--- Huella que muestra ssh al conectarse por primera vez (known_hosts vacio):"
sshpass -e sftp -v -o BatchMode=no -o StrictHostKeyChecking=accept-new -P 2222 -b /dev/null $U@$PUB 2>&1 \
  | grep -E 'Server host key|Permanently added|Authenticated to'
echo "--- known_hosts despues de la primera conexion:"
ssh-keygen -lf ~/.ssh/known_hosts

echo
echo "--- Sesion SFTP: ls, put y get (sftp -P 2222 $U@$PUB)"
sshpass -e sftp -o BatchMode=no -P 2222 -b /vagrant/scripts/sftp_lote.txt $U@$PUB
echo "--- Comparacion local del archivo subido y el descargado:"
diff 1005968285_sftp.txt descargado_sftp.txt && echo "IDENTICOS: $(cat descargado_sftp.txt)"

echo
echo "################ 18) Captura SFTP (tcp.port == 2222) ################"
bash /vagrant/scripts/captura.sh eth1 18_sftp_tcp2222.pcap "tcp port 2222" \
  "SSHPASS=$SSHPASS sshpass -e sftp -o BatchMode=no -P 2222 -b /vagrant/scripts/sftp_lote.txt $U@$PUB >/dev/null"
P=/vagrant/capturas/18_sftp_tcp2222.pcap
D="-d tcp.port==2222,ssh"
echo "--- Intercambio de versiones (Protocol: SSH-2.0) y mensajes de negociacion:"
tshark -r $P $D -Y 'ssh.protocol or ssh.message_code' -T fields -E separator='|' \
  -e frame.number -e ip.src -e tcp.srcport -e ssh.protocol -e _ws.col.Info 2>/dev/null | head -12
echo "--- Algoritmos ofrecidos por el cliente en KEXINIT (resumen):"
tshark -r $P $D -Y 'ssh.message_code==20' -T fields -e ip.src -e ssh.kex_algorithms 2>/dev/null | cut -c1-160
echo "--- Paquetes cifrados despues de NEWKEYS (Encrypted packet):"
tshark -r $P $D -Y 'ssh.encrypted_packet' 2>/dev/null | wc -l
echo -n "--- Contrasena en claro en la captura: "
tshark -r $P -x 2>/dev/null | grep -c 'Sftp.1005' | awk '{print $1 " coincidencias"}'
echo -n "--- Contenido del archivo en claro en la captura: "
tshark -r $P -x 2>/dev/null | grep -c 'Panesso' | awk '{print $1 " coincidencias"}'
echo "--- Conversaciones TCP (una sola conexion para autenticacion + comandos + datos):"
tshark -r $P -q -z conv,tcp 2>/dev/null | sed -n '5,12p'
