#!/usr/bin/env bash
# Verificacion de punta a punta del parcial (se ejecuta desde el anfitrion, en E:\parcial2).
#   bash scripts/verificar_todo.sh | tee evidencias/99_verificacion_final.txt
# Cada prueba imprime PASS/FAIL. Deja el firewall en el estado inicial (sin la regla SFTP).
cd "$(dirname "$0")/.." || exit 1
export VAGRANT_HOME='E:\VagrantHome'
PASS=0; FAIL=0
FTP='curl -sS --connect-timeout 6 --ssl-reqd --cacert /vagrant/certs/ca.crt --user ftp_1005968285:Ftps.1005968285'
SFTP='SSHPASS=Sftp.1005968285 timeout 20 sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -P 2222'

# t "<descripcion>" <maquina> "<comando>" <esperado: 0=debe funcionar | 1=debe fallar> ["<regex que debe aparecer>"]
t() {
  local d="$1" m="$2" c="$3" e="$4" g="${5:-}" out rc ok=1
  out=$(vagrant ssh "$m" -c "$c" 2>&1); rc=$?
  if [ "$e" = 0 ]; then [ $rc -eq 0 ] || ok=0; else [ $rc -ne 0 ] || ok=0; fi
  if [ -n "$g" ] && ! grep -qE "$g" <<<"$out"; then ok=0; fi
  if [ $ok -eq 1 ]; then
    PASS=$((PASS+1)); echo "PASS  $d"
  else
    FAIL=$((FAIL+1)); echo "FAIL  $d"
    echo "$out" | grep -v '^Connection to' | head -6 | sed 's/^/      > /'
  fi
}

echo "######## $(date '+%F %T')  Verificacion del parcial con public_network ########"

echo; echo "== 0. Entorno y redes"
t "srv1 responde" srv1 "true" 0
t "srv1: eth1 192.168.56.10 y eth2 192.168.50.3" srv1 "ip -br -4 addr" 0 "192.168.56.10"
t "srv1: eth2 en la red interna 192.168.50.3" srv1 "ip -br -4 addr show eth2" 0 "192.168.50.3"
t "srv1: public_network con IP de la LAN (eth3)" srv1 "ip -br -4 addr show eth3" 0 "192\.168\.[0-9]+\.[0-9]+"
t "cliente: public_network con IP de la LAN (eth2)" cliente "ip -br -4 addr show eth2" 0 "192\.168\.[0-9]+\.[0-9]+"
t "srv2: solo red interna 192.168.50.2" srv2 "ip -br -4 addr show eth1" 0 "192.168.50.2"
t "hostname srv1 con el codigo" srv1 "hostname" 0 "srv1-1005968285"
t "hostname srv2 con el codigo" srv2 "hostname" 0 "srv2-1005968285"
t "hostname cliente con el codigo" cliente "hostname" 0 "cliente-1005968285"

echo; echo "== PRIMERA PARTE: FTPS + UFW"
t "P1  UFW activo con deny incoming / deny routed" srv1 "sudo ufw status verbose" 0 "deny \(incoming\), allow \(outgoing\), deny \(routed\)"
t "P1  reenvio IP habilitado" srv1 "sysctl -n net.ipv4.ip_forward" 0 "^1"
t "P1  DNAT 21 y 50000:50010 en before.rules" srv1 "sudo grep -E '^-A PREROUTING.*--dport (21|50000:50010) -j DNAT' /etc/ufw/before.rules | wc -l" 0 "^2"
t "P1  el cliente NO tiene ruta hacia 192.168.50.0/24 (sale por NAT)" cliente "ip route get 192.168.50.2 | grep -q 'via 10.0.2.2'" 0
t "P1  srv2:21 NO alcanzable desde el cliente" cliente "nc -z -w3 192.168.50.2 21" 1
t "P1  srv2:22 NO alcanzable desde el cliente" cliente "nc -z -w3 192.168.50.2 22" 1
t "P2  reglas UFW ALLOW: 22, 22(v6), route 21, route 50000:50010 (y nada mas)" srv1 "sudo ufw status | grep -cE 'ALLOW'" 0 "^4$"
t "P2  no hay regla route hacia el 22 (SFTP) al inicio" srv1 "sudo ufw status | grep -E '192.168.50.2 22/tcp'" 1
t "P2  puertos extra cerrados desde el cliente (80, 443, 3306)" cliente 'for p in 80 443 3306; do nc -z -w2 192.168.56.10 $p && exit 1; done; exit 0' 0
t "P3  quitar la regla route del 21" srv1 "sudo bash /vagrant/scripts/11_srv1_permitir_ftp.sh quitar" 0
t "P3  SIN la regla el FTPS falla (timeout)" cliente "$FTP ftp://192.168.56.10/" 1
t "P3  agregar la regla route del 21" srv1 "sudo bash /vagrant/scripts/11_srv1_permitir_ftp.sh" 0
t "P3  CON la regla el FTPS funciona" cliente "$FTP ftp://192.168.56.10/" 0 "bienvenida.txt"
t "P4  reglas NAT activas (iptables -t nat)" srv1 "sudo iptables -t nat -L PREROUTING -n -v" 0 "DNAT.*dpt:21 to:192.168.50.2:21"
t "P5  vsftpd activo y escuchando en el 21" srv2 "systemctl is-active vsftpd && sudo ss -ltn | grep -q ':21 '" 0
t "P5  TLS obligatorio y SSLv2/v3 deshabilitados" srv2 "grep -E '^(force_local_logins_ssl=YES|force_local_data_ssl=YES|ssl_sslv2=NO|ssl_sslv3=NO)' /etc/vsftpd.conf | wc -l" 0 "^4"
t "P5  certificado firmado por la CA" srv2 "openssl verify -CAfile /vagrant/certs/ca.crt /etc/ssl/parcial2/servidor.crt" 0 ": OK"
t "P5  login SIN TLS rechazado (530)" cliente "curl -sS --connect-timeout 6 --user ftp_1005968285:Ftps.1005968285 ftp://192.168.56.10/" 1 "530"
t "P6  rango pasivo y pasv_address" srv2 "grep -E '^(pasv_min_port=50000|pasv_max_port=50010|pasv_address=192.168.56.10)' /etc/vsftpd.conf | wc -l" 0 "^3"
t "P7  subir/descargar por FTPS explicito (lftp)" cliente "echo 'Archivo de prueba del parcial - Juan Esteban Panesso 1005968285' > ~/1005968285.txt; rm -f ~/descargado_lftp.txt; lftp -f /vagrant/scripts/lftp_ftps.lftp >/dev/null" 0
t "P7  archivo descargado identico al original" cliente "cmp ~/1005968285.txt ~/descargado_lftp.txt" 0
t "P7  huella SHA-256 del certificado" cliente "openssl x509 -in /vagrant/certs/servidor.crt -noout -fingerprint -sha256" 0 "D8:C6:48:9B"
echo -n "PASS?  Windows (anfitrion) -> FTPS 192.168.56.10, como FileZilla: "
if curl.exe -sS --ssl-reqd --ssl-no-revoke --cacert 'E:\parcial2\certs\ca.crt' --user ftp_1005968285:Ftps.1005968285 ftp://192.168.56.10/ 2>&1 | grep -q bienvenida; then echo "OK"; PASS=$((PASS+1)); else echo "FALLO"; FAIL=$((FAIL+1)); fi
t "P8  openssl s_client con CA: Verify return code 0" cliente "echo QUIT | openssl s_client -connect 192.168.56.10:21 -starttls ftp -CAfile /vagrant/certs/ca.crt 2>&1" 0 "Verify return code: 0 \(ok\)"
t "P8  TLS 1.3 y suite AES-256-GCM-SHA384" cliente "echo QUIT | openssl s_client -connect 192.168.56.10:21 -starttls ftp -CAfile /vagrant/certs/ca.crt 2>&1" 0 "TLS_AES_256_GCM_SHA384"
t "P8  sin la CA: Verify return code 21" cliente "echo QUIT | openssl s_client -connect 192.168.56.10:21 -starttls ftp 2>&1" 0 "Verify return code: 21"
t "P9  TLS off en vsftpd" srv2 "sudo bash /vagrant/scripts/21_srv2_tls_on_off.sh off" 0 "ssl_enable=NO"
t "P9  FTP plano lista el directorio (USER/PASS en claro)" cliente "curl -sS --connect-timeout 6 --user ftp_1005968285:Ftps.1005968285 ftp://192.168.56.10/" 0 "bienvenida.txt"
t "P9  TLS on en vsftpd (vuelve el FTPS)" srv2 "sudo bash /vagrant/scripts/21_srv2_tls_on_off.sh on" 0 "ssl_enable=YES"
t "P9  capturas 09a y 09b existen" cliente "ls -l /vagrant/capturas/09a_ftp_plano.pcap /vagrant/capturas/09b_ftps.pcap" 0

echo; echo "== SEGUNDA PARTE: DNS sobre TLS (cliente)"
t "P10 resolved.conf: DNS con #nombre, FallbackDNS y DNSOverTLS=yes" cliente "grep -E '^(DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google|DNSOverTLS=yes|FallbackDNS=)' /etc/systemd/resolved.conf | wc -l" 0 "^3"
t "P10 /etc/resolv.conf apunta al stub 127.0.0.53" cliente "grep -q 'nameserver 127.0.0.53' /etc/resolv.conf && readlink /etc/resolv.conf" 0 "stub-resolv.conf"
t "P11 resolvectl status muestra +DNSOverTLS" cliente "resolvectl status" 0 "\+DNSOverTLS"
t "P11 ninguna interfaz trae DNS propios (la public_network no los filtra)" cliente "resolvectl dns | grep -E 'Link [0-9]+ \(eth[0-9]\): [0-9a-f]' | wc -l" 0 "^0"
t "P12 3 dominios resueltos por transporte cifrado" cliente 'for d in uao.edu.co github.com wikipedia.org; do resolvectl query $d | grep -q "encrypted transport: yes" || exit 1; done' 0
t "P12 dig sin @ pasa por 127.0.0.53" cliente "dig www.google.com | grep SERVER" 0 "127.0.0.53"
t "P12 dig @8.8.8.8 va directo por UDP/53 (sin DoT)" cliente "dig @8.8.8.8 www.google.com | grep SERVER" 0 "8.8.8.8#53.*UDP"

echo "  ... P13/P14: capturas 853 vs 53 y bloqueo del 853 (scripts/41_cliente_capturas_dot.sh)"
OUT41=$(vagrant ssh cliente -c "bash /vagrant/scripts/41_cliente_capturas_dot.sh" 2>&1)
chk() { if grep -qE "$2" <<<"$OUT41"; then PASS=$((PASS+1)); echo "PASS  $1"; else FAIL=$((FAIL+1)); echo "FAIL  $1"; fi; }
chk "P13 DoT: Client Hello a 1.1.1.1:853 con SNI cloudflare-dns.com" "1\.1\.1\.1\|853\|cloudflare-dns\.com"
chk "P13 DoT: 0 paquetes UDP/53 durante la captura" "debe ser 0\):"$'\r?\n'"?0"
chk "P13 DoT: 0 consultas DNS legibles en la captura" "claro en la captura DoT: 0"
chk "P13 sin DoT: consultas DNS visibles en claro (example.com)" "\|53\|0\|example\.com"
chk "P14 puerto 853 bloqueado + yes: la resolucion falla" "resolve call failed"
chk "P14 puerto 853 bloqueado + opportunistic: degrada y resuelve" "opportunistic"$'\r?\n'"?wikipedia\.org: [0-9a-f]"
chk "P14 estado final: DoT estricto (+DNSOverTLS)" "Protocols: .*\+DNSOverTLS"

echo; echo "== TERCERA PARTE: SFTP + UFW"
t "P15 Match User con chroot e internal-sftp" srv2 "sudo sshd -T -C user=sftp_1005968285,host=x,addr=192.168.56.20 | grep -E '^(chrootdirectory /srv/sftp/%u|forcecommand internal-sftp)' | wc -l" 0 "^2"
t "P16 DNAT 2222 -> 22 activo" srv1 "sudo iptables -t nat -L PREROUTING -n | grep -E 'dpt:2222 to:192.168.50.2:22'" 0
t "P16 SIN la regla route el SFTP falla" cliente "echo ls | $SFTP sftp_1005968285@192.168.56.10" 1
t "P16 agregar la regla route del 22" srv1 "sudo bash /vagrant/scripts/31_srv1_sftp_reenvio.sh permitir" 0
t "P16 CON la regla el SFTP funciona (ls)" cliente "echo 'ls -l' | $SFTP sftp_1005968285@192.168.56.10" 0 "leeme.txt"
t "P15 shell SSH rechazada para el usuario SFTP" cliente "SSHPASS=Sftp.1005968285 sshpass -e ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 sftp_1005968285@192.168.56.10 id" 1 "sftp connections only"
t "P15 usuario enjaulado (cd /etc falla)" cliente "printf 'cd /etc\n' > /tmp/j.txt; $SFTP -b /tmp/j.txt sftp_1005968285@192.168.56.10" 1
t "P16 puerto 22 de srv2 NO alcanzable directamente" cliente "nc -z -w3 192.168.50.2 22" 1
t "P17 huella de la clave de host (ssh-keyscan por el 2222)" cliente "ssh-keyscan -p 2222 -t ed25519 192.168.56.10 2>/dev/null | ssh-keygen -lf -" 0 "SHA256:"
t "P17/18 ls, put, get y captura tcp/2222" cliente "bash /vagrant/scripts/50_cliente_sftp.sh" 0 "IDENTICOS"
t "P18 captura SFTP: 1 sola conexion TCP" cliente "tshark -r /vagrant/capturas/18_sftp_tcp2222.pcap -q -z conv,tcp 2>/dev/null | grep -c '<->'" 0 "^1$"
t "P18 captura SFTP: contrasena y contenido NO aparecen en claro" cliente "tshark -r /vagrant/capturas/18_sftp_tcp2222.pcap -x 2>/dev/null | grep -cE 'Sftp.1005|Panesso'" 1 "^0$"
t "Volver al estado inicial: quitar la regla route del 22" srv1 "sudo bash /vagrant/scripts/31_srv1_sftp_reenvio.sh quitar" 0

echo; echo "== SEGURIDAD de la red publica (desde el anfitrion Windows)"
LANIP=$(vagrant ssh srv1 -c "ip -4 -o addr show eth3 | awk '{print \$4}' | cut -d/ -f1" 2>/dev/null | tr -d '\r\n')
for p in 21 2222 50000; do
  echo -n "      $LANIP:$p desde la LAN real (debe estar cerrado): "
  if powershell -NoProfile -Command "(Test-NetConnection $LANIP -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded" | grep -q True; then echo "FALLO (abierto)"; FAIL=$((FAIL+1)); else echo "PASS (cerrado)"; PASS=$((PASS+1)); fi
done
t "SSH de srv1 solo por llave (la contrasena se rechaza)" cliente "SSHPASS=vagrant sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o ConnectTimeout=6 vagrant@192.168.56.10 hostname" 1 "publickey"
t "Estado final de srv1: UFW sin la regla SFTP" srv1 "sudo ufw status | grep -E '192.168.50.2 22/tcp'" 1

echo; echo "######## RESULTADO: $PASS pruebas OK, $FAIL fallidas ########"
