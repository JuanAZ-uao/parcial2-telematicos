#!/usr/bin/env bash
# Genera la CA del curso y el certificado del servidor FTPS con OpenSSL
# (no se tenia la CA de clase, se regenera con el mismo procedimiento).
# Ejecutar en srv2:  sudo bash /vagrant/scripts/05_certs_srv2.sh
set -euo pipefail
CODIGO=1005968285
IP_PUBLICA=192.168.56.10
D=/vagrant/certs
mkdir -p "$D"; cd "$D"

if [ ! -f ca.crt ]; then
  # 1) CA raiz (autofirmada, 10 anios)
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.crt \
    -subj "/C=CO/ST=Valle del Cauca/L=Cali/O=UAO/OU=Servicios Telematicos/CN=CA Telematicos ${CODIGO}"
fi

if [ ! -f servidor.crt ]; then
  # 2) Clave y CSR del servidor
  openssl genrsa -out servidor.key 2048
  openssl req -new -key servidor.key -out servidor.csr \
    -subj "/C=CO/ST=Valle del Cauca/L=Cali/O=UAO/OU=Servicios Telematicos/CN=${IP_PUBLICA}"
  # 3) Firma con la CA. El SAN incluye la IP publica: el cliente se conecta a
  #    192.168.56.10 y la validacion del nombre se hace contra el SAN.
  cat > servidor.ext <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=IP:${IP_PUBLICA},DNS:srv2-${CODIGO}
EOF
  openssl x509 -req -in servidor.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out servidor.crt -days 825 -sha256 -extfile servidor.ext
fi

# 4) Instalacion para vsftpd
install -d -m 755 /etc/ssl/parcial2
install -m 644 servidor.crt ca.crt /etc/ssl/parcial2/
install -m 600 servidor.key /etc/ssl/parcial2/

openssl verify -CAfile ca.crt servidor.crt
openssl x509 -in servidor.crt -noout -subject -issuer -dates -ext subjectAltName
openssl x509 -in servidor.crt -noout -fingerprint -sha256
