#!/usr/bin/env bash
# Captura trafico mientras se ejecuta un comando y guarda el .pcap en /vagrant/capturas.
#   bash /vagrant/scripts/captura.sh <interfaz> <archivo.pcap> "<filtro tcpdump>" "<comando>"
# Los .pcap se abren despues en Wireshark (Windows): E:\parcial2\capturas\
set -uo pipefail
IFACE="$1"; OUT="$2"; FILTRO="$3"; CMD="$4"
TMP="/tmp/$(basename "$OUT")"
sudo rm -f "$TMP"
sudo tcpdump -i "$IFACE" -U -s 0 -w "$TMP" "$FILTRO" 2>/dev/null &
sleep 2
bash -c "$CMD"
sleep 2
sudo pkill -INT -f "tcpdump -i $IFACE" ; sleep 1
mkdir -p /vagrant/capturas
sudo cp "$TMP" "/vagrant/capturas/$(basename "$OUT")"
echo "Captura guardada: capturas/$(basename "$OUT") ($(sudo tcpdump -r "$TMP" 2>/dev/null | wc -l) paquetes)"
