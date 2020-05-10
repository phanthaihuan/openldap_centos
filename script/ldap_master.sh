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

if [ -n "$(ls -A $configdir)" ] && [ -n "$(ls -A $datadir)" ]; then
    chown -R ldap:ldap $configdir
    chown -R ldap:ldap $datadir
    echo -e "$RED Config folder and data folder are not empty.$NC"
    echo -e "$RED Starting OpenLDAP with existing configuration.$NC"
    systemctl restart slapd
    systemctl enable slapd
    STATUS="$(systemctl is-active slapd)"
    if [ "${STATUS}" = "active" ]; then
        echo -e "$GREEN slapd is started with existing configuration.$NC"
        /bin/bash
    else
        echo -e "$RED Something went wrong with existing configuration.$NC"
        echo -e "$YELLOW Press Enter to exit.$NC"
        read -p ""
        exit 1
    fi    
else
    echo -e "$GREEN Config folder and data folder are both empty.$NC"
    echo -e "$GREEN Starting to build OpenLDAP master. $NC"

    cp /root/tmp/openldap/* /etc/openldap/ -rfa
    cp /root/tmp/ldap/* /var/lib/ldap/ -rfa
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown ldap.ldap /var/lib/ldap/DB_CONFIG

    systemctl restart slapd &
    systemctl enable slapd

    echo -e "$GREEN Building chrootpw.ldif$NC"
    HASHED_PASS=`slappasswd -s $LDAP_PASS`
    sed -i 's/olcRootPW:.*/olcRootPW: $HASHED_PASS/g' /chrootpw.ldif

    echo -e "$GREEN Import chrootpw.ldif to OpenLDAP.$NC"
    ldapadd -Y EXTERNAL -H ldapi:/// -f /chrootpw.ldif

    echo -e "$GREEN Import basic schema to OpenLDAP.$NC"
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

    echo -e "$GREEN Building db.ldif$NC"
    sed -i 's/olcRootPW:.*/olcRootPW: $HASHED_PASS/g' /etc/openldap/slapd.d/db.ldif
    ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/slapd.d/db.ldif
    ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/slapd.d/monitor.ldif

    ldapadd -x -w $LDAP_PASS -D "cn=ldapadm,dc=ldap,dc=mydomain,dc=com" \
            -f /etc/openldap/slapd.d/base.ldif

    echo -e "$GREEN Add syncprov module for replication.$NC"
    echo '
    dn: cn=module,cn=config
    objectClass: olcModuleList
    cn: module
    olcModulePath: /usr/lib64/openldap
    olcModuleLoad: syncprov.la' > mod_syncprov.ldif

    ldapadd -Y EXTERNAL -H ldapi:/// -f mod_syncprov.ldif
    echo -e "$GREEN syncprov module is added.$NC"

    echo -e "$GREEN Allowed module syncprov on DB LDAP.$NC"
    echo '
    dn: olcOverlay=syncprov,olcDatabase={2}hdb,cn=config
    objectClass: olcOverlayConfig
    objectClass: olcSyncProvConfig
    olcOverlay: syncprov
    olcSpSessionLog: 100' > syncprov.ldif

    ldapadd -Y EXTERNAL -H ldapi:/// -f syncprov.ldif
    echo -e "$GREEN module syncprov is allowed on DB LDAP.$NC"

    systemctl restart slapd &
    STATUS="$(systemctl is-active slapd)"
    if [ "${STATUS}" = "active" ]; then
        echo -e "$GREEN slapd is started with master configuration.$NC"
        /bin/bash
    else
        echo -e "$RED Something went wrong with master configuration.$NC"
        echo -e "$YELLOW Press Enter to exit.$NC"
        read -p ""
        exit 1
    fi  
    /bin/bash
fi

exit 0

