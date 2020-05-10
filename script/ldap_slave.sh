#!/bin/bash
set -e
RED='\033[0;31m'
GREEN='\033[1;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

configdir="/etc/openldap"
datadir="/var/lib/ldap"

LDAP_PASS='admin@ldap'

LDAP_MASTER_IP="$1"
LDAP_MASTER_PORT="$2"

if [ -n "$(ls -A $configdir)" ] && [ -n "$(ls -A $datadir)" ]; then
    echo - "$RED Config folder and data folder are not empty.$NC"
    echo - "$RED Please emtpy these folders before configure slave.$NC"
    read -p "$YELLOW Press Enter to exit.$NC" 
    /bin/bash 
else
    echo - "$GREEN Config folder and data folder are both empty.$NC"
    echo - "$GREEN Starting to build OpenLDAP slave. $NC"
    
    systemctl start slapd &
    systemctl enable slapd

    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

    ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/slapd.d/db.ldif
    ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/slapd.d/monitor.ldif

    ldapadd -x -w $LDAP_PASS -D "cn=ldapadm,dc=ldap,dc=mydomain,dc=com" \
            -f /etc/openldap/slapd.d/base.ldif

    # Configure OpenLDAP slave
    cat > syncrepl.ldif << EOF
      dn: olcDatabase={2}hdb,cn=config
      changetype: modify
      add: olcSyncRepl
      olcSyncRepl: rid=001
      provider=ldap://$LDAP_MASTER_IP:$LDAP_MASTER_PORT/
      bindmethod=simple
      binddn="cn=ldapadm,dc=ldap,dc=mydomain,dc=com"
      credentials=$LDAP_PASS
      searchbase="dc=ldap,dc=mydomain,dc=com"
      scope=sub
      schemachecking=on
      type=refreshAndPersist
      retry="30 5 300 3"
      interval=00:00:05:00 
EOF

      ldapadd -Y EXTERNAL -H ldapi:/// -f syncrepl.ldif

      systemctl restart slapd &
      STATUS="$(systemctl is-active slapd)"
      if [ "${STATUS}" = "active" ]; then
          echo - "$GREEN slapd is started in slave mode.$NC"
          /bin/bash
      else
          echo -e "$RED Something went wrong when slave mode.$NC"
          echo -e "$YELLOW Press Enter to exit.$NC"
          read -p ""
          exit 1
      fi  
fi

exit 0

