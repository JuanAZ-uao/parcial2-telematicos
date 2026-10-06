# Segundo Parcial — Servicios Telemáticos (UAO, 2026-02)

FTPS protegido por firewall UFW, DNS sobre TLS (DoT) y SFTP protegido por firewall UFW,
implementados con Vagrant + VirtualBox (Ubuntu 22.04, box `bento/ubuntu-22.04`).

**Integrantes**

| Nombre | Código |
|---|---|
| Juan Esteban Panesso | 1005968285 |
| Sebastián Castillo Acevedo | 1109116367 |
| Samuel Ríos | 1109663704 |

> Los hostnames, el usuario FTP/SFTP y el archivo de prueba usan el código `1005968285`.

## Topología y direccionamiento

```
                      red "pública" 192.168.56.0/24 (host-only)
  ┌──────────────────────┐                 ┌───────────────────────────────┐
  │ cliente-1005968285   │  eth1           │ srv1-1005968285 (UFW + DNAT)  │
  │ 192.168.56.20        ├────────────────►│ eth1 192.168.56.10 <ip pública>│
  │ lftp, curl, sftp,    │  21, 2222,      │ eth2 192.168.50.3             │
  │ openssl, tshark, DoT │  50000-50010    └──────────────┬────────────────┘
  └──────────────────────┘                                │ red interna 192.168.50.0/24
                                                          │ (intnet de VirtualBox, aislada)
                                           ┌──────────────┴────────────────┐
                                           │ srv2-1005968285               │
                                           │ eth1 192.168.50.2             │
                                           │ vsftpd (FTPS) + OpenSSH (SFTP)│
                                           └───────────────────────────────┘
```

| Rol | Hostname | IP | Servicio |
|---|---|---|---|
| Servidor 1 | `srv1-1005968285` | **192.168.56.10** (`<ip pública>`), 192.168.50.3 | UFW, DNAT, reenvío IP |
| Servidor 2 | `srv2-1005968285` | 192.168.50.2 (solo red interna) | vsftpd FTPS, OpenSSH/SFTP |
| Cliente | `cliente-1005968285` | 192.168.56.20 | Cliente FTPS/SFTP, DoT con systemd-resolved |

**Direccionamiento propio:** la `<ip pública>` del enunciado es **192.168.56.10**. La red entre
los servidores es una *internal network* de VirtualBox, así que ni el cliente ni el host Windows
tienen ruta hacia 192.168.50.0/24. El Servidor 2 tiene una ruta estática hacia 192.168.56.0/24
por 192.168.50.3 (`config/srv2/60-ruta-cliente.yaml`) para que las respuestas vuelvan por el firewall.

**`public_network` (red puenteada).** `srv1` y `cliente` tienen además un adaptador
`public_network` del `Vagrantfile`, puenteado a la tarjeta de red del equipo anfitrión y con IP por
DHCP de la LAN real (en las pruebas: `srv1` 192.168.1.36, `cliente` 192.168.1.37). Ese adaptador
solo aporta la IP: [`scripts/01_red_publica.sh`](scripts/01_red_publica.sh) le quita la ruta por
defecto y el DNS del router para no alterar la topología (el cliente sigue sin ruta hacia
192.168.50.0/24 y el DoT usa solo los resolvers de `resolved.conf`). El DNAT es solo por `eth1`
(`-i eth1`), así que el 21, el 50000:50010 y el 2222 **no** se publican hacia la LAN real. Como el
Servidor 1 queda con IP en esa red, [`scripts/02_srv1_endurecer_ssh.sh`](scripts/02_srv1_endurecer_ssh.sh)
deshabilita la autenticación por contraseña de su SSH (solo llaves). Si la tarjeta del anfitrión
tiene otro nombre, se cambia en la variable `BRIDGE` del `Vagrantfile`.

| Servicio publicado en 192.168.56.10 | Reenviado a | Regla |
|---|---|---|
| 22/tcp | — (SSH de administración del Servidor 1) | `ufw allow 22/tcp` |
| 21/tcp | 192.168.50.2:21 | DNAT + `ufw route allow … port 21` |
| 50000:50010/tcp | 192.168.50.2:50000-50010 | DNAT + `ufw route allow … port 50000:50010` |
| 2222/tcp | 192.168.50.2:22 | DNAT + `ufw route allow … port 22` |

## Archivos de configuración entregados

| Archivo | Máquina | Ruta real |
|---|---|---|
| [`config/srv1/before.rules`](config/srv1/before.rules) | srv1 | `/etc/ufw/before.rules` (bloque `*nat` con los DNAT) |
| [`config/srv1/user.rules`](config/srv1/user.rules) | srv1 | `/etc/ufw/user.rules` (reglas `allow` y `route allow`) |
| [`config/srv1/ufw.default`](config/srv1/ufw.default) | srv1 | `/etc/default/ufw` |
| [`config/srv1/ufw-sysctl.conf`](config/srv1/ufw-sysctl.conf) | srv1 | `/etc/ufw/sysctl.conf` (`net/ipv4/ip_forward=1`) |
| [`config/srv2/vsftpd.conf`](config/srv2/vsftpd.conf) | srv2 | `/etc/vsftpd.conf` |
| [`config/srv2/sshd_config`](config/srv2/sshd_config) | srv2 | `/etc/ssh/sshd_config` (bloque `Match User`) |
| [`config/cliente/resolved.conf`](config/cliente/resolved.conf) | cliente | `/etc/systemd/resolved.conf` |
| [`config/cliente/networkd-sin-dns.conf`](config/cliente/networkd-sin-dns.conf) | cliente | drop-in de systemd-networkd (ignora el DNS del DHCP) |
| [`certs/ca.crt`](certs/ca.crt), [`certs/servidor.crt`](certs/servidor.crt) | srv2 / cliente | CA y certificado del servidor FTPS |

> Las claves privadas (`certs/*.key`) **no** se suben al repositorio (`.gitignore`).
> No se contaba con la CA generada en clase, así que se regeneró con el mismo procedimiento
> de OpenSSL: [`scripts/05_certs_srv2.sh`](scripts/05_certs_srv2.sh).

## Evidencias

Salidas de comandos en [`evidencias/`](evidencias/) y capturas para Wireshark en [`capturas/`](capturas/).

| Punto | Evidencia |
|---|---|
| 1, 2 | [`01_02_srv1_ufw.txt`](evidencias/01_02_srv1_ufw.txt), [`01_srv2_inalcanzable.txt`](evidencias/01_srv2_inalcanzable.txt) |
| 3 | [`03_control_acceso_ftp.txt`](evidencias/03_control_acceso_ftp.txt): falla sin la regla del 21, funciona con ella |
| 4 | [`04_ufw_y_nat.txt`](evidencias/04_ufw_y_nat.txt) |
| 5, 6 | [`05_06_srv2_vsftpd.txt`](evidencias/05_06_srv2_vsftpd.txt) |
| 7 | [`07_transferencia_ftps.txt`](evidencias/07_transferencia_ftps.txt) + capturas de FileZilla en [`evidencias/img/`](evidencias/img/) |
| 8 | [`08_openssl_s_client.txt`](evidencias/08_openssl_s_client.txt): `Verify return code: 0 (ok)`, TLSv1.3 |
| 9 | [`09_capturas_ftp_ftps.txt`](evidencias/09_capturas_ftp_ftps.txt), `capturas/09a_ftp_plano.pcap`, `capturas/09b_ftps.pcap` |
| 10 | [`10_resolved_conf.txt`](evidencias/10_resolved_conf.txt) |
| 11 | [`11_resolvectl_status.txt`](evidencias/11_resolvectl_status.txt) |
| 12 | [`12_consultas_dns.txt`](evidencias/12_consultas_dns.txt) |
| 13, 14 | [`13_14_capturas_dot.txt`](evidencias/13_14_capturas_dot.txt), `capturas/13a_dot_tcp853.pcap`, `capturas/13b_dns_udp53.pcap` |
| 15 | [`15_sftp_chroot.txt`](evidencias/15_sftp_chroot.txt) |
| 16 | [`16_reenvio_2222.txt`](evidencias/16_reenvio_2222.txt) |
| 17, 18 | [`17_18_sftp_cliente.txt`](evidencias/17_18_sftp_cliente.txt), `capturas/18_sftp_tcp2222.pcap` |
| Final | [`99_estado_final.txt`](evidencias/99_estado_final.txt): escaneo de puertos desde el cliente |

Las explicaciones de cada punto (preguntas teóricas, tabla comparativa y conclusión) se presentan
en la sustentación.

## Cómo reproducir

Requisitos: VirtualBox 7.x y Vagrant. En equipos con Hyper-V activo (WSL2/Docker), el
`Vagrantfile` ya fija 1 CPU, paravirtualización KVM y 1 puerto SATA para que las VMs arranquen.

```bash
vagrant up                      # crea srv1, srv2 y cliente (paquetes base)

# PRIMERA PARTE
vagrant ssh srv2 -c "sudo bash /vagrant/scripts/20_srv2_vsftpd.sh"        # CA + certificado + vsftpd FTPS
vagrant ssh srv1 -c "sudo bash /vagrant/scripts/10_srv1_ufw.sh"           # UFW + DNAT (sin la regla del 21)
vagrant ssh srv1 -c "sudo bash /vagrant/scripts/11_srv1_permitir_ftp.sh"  # agrega route allow del 21

# SEGUNDA PARTE
vagrant ssh cliente -c "sudo bash /vagrant/scripts/40_cliente_dot.sh yes"
vagrant ssh cliente -c "bash /vagrant/scripts/41_cliente_capturas_dot.sh"

# TERCERA PARTE
vagrant ssh srv2 -c "sudo bash /vagrant/scripts/30_srv2_sftp.sh"
vagrant ssh srv1 -c "sudo bash /vagrant/scripts/31_srv1_sftp_reenvio.sh nat"
vagrant ssh srv1 -c "sudo bash /vagrant/scripts/31_srv1_sftp_reenvio.sh permitir"
vagrant ssh cliente -c "bash /vagrant/scripts/50_cliente_sftp.sh"
```

Credenciales de laboratorio (solo existen dentro de las VMs):

| Usuario | Contraseña | Uso |
|---|---|---|
| `ftp_1005968285` | `Ftps.1005968285` | FTPS (vsftpd) |
| `sftp_1005968285` | `Sftp.1005968285` | SFTP enjaulado |
