# Credit to https://gist.github.com/thbkrkr

TLS="/etc/pki/tls/certs"
TARGET="/etc/openldap/certs"

cd $TLS
# Generate a passphrase
openssl rand -base64 48 > $TLS/passphrase.txt

# Generate a Private Key
openssl genrsa -aes128 -passout file:$TLS/passphrase.txt -out $TLS/server.key 2048

# Generate a CSR (Certificate Signing Request)
openssl req -new -passin file:$TLS/passphrase.txt -key $TLS/server.key -out $TLS/server.csr -subj "/C=VN/O=Asean Fan/OU=System Engineer Team/CN=*.aseanfan.com"

# Remove Passphrase from Key
cp $TLS/server.key $TLS/server.key.org
openssl rsa -in $TLS/server.key.org -passin file:$TLS/passphrase.txt -out $TLS/server.key

# Generating a Self-Signed Certificate for 10 year
openssl x509 -req -days 3650 -in $TLS/server.csr -signkey $TLS/server.key -out $TLS/server.crt

/usr/bin/cp $TLS/server.key $TLS/server.crt $TLS/ca-bundle.crt $TARGET
chown -R ldap:ldap $TARGET