#!/usr/bin/env bash
# Agrega "-F PREROUTING" al bloque *nat de before.rules (si falta) para que
# "ufw reload" no duplique las reglas DNAT. Idempotente.
set -euo pipefail
F=/etc/ufw/before.rules
if ! grep -q '^-F PREROUTING' "$F"; then
  awk '{print} /^:POSTROUTING ACCEPT \[0:0\]$/ && !d {print "# UFW no vacia la tabla nat al recargar: sin esto cada \"ufw reload\" duplica las reglas"; print "-F PREROUTING"; d=1}' "$F" > /tmp/before.rules
  install -m 640 /tmp/before.rules "$F"
fi
ufw reload
ufw reload
iptables -t nat -L PREROUTING -n --line-numbers
