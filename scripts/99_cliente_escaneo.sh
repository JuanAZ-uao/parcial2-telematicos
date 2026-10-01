#!/usr/bin/env bash
# Comprobacion final desde el cliente: que puertos responde la IP publica del Servidor 1
# y que el Servidor 2 sigue sin ser alcanzable directamente.
for p in 21 22 80 443 2222 3306 8080 50000 50005 50010 50011; do
  if nc -z -w2 192.168.56.10 $p 2>/dev/null; then e="ABIERTO"; else e="cerrado/filtrado"; fi
  printf "192.168.56.10:%-6s %s\n" "$p" "$e"
done
echo
for p in 21 22; do
  if nc -z -w3 192.168.50.2 $p 2>/dev/null; then e="ALCANZABLE (mal)"; else e="inalcanzable (ok)"; fi
  printf "192.168.50.2:%-6s %s\n" "$p" "$e"
done
