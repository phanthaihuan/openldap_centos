#!/bin/bash
set -e
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

configdir="/etc/openldap"
datadir="/var/lib/ldap"

ADMIN_LDAP="ldapadm"
DC1="mydomain"
DC2="com"

LDAP_PASS='adminldap'

if [ -n "$(ls -A $configdir)" ] && [ -n "$(ls -A $datadir)" ]; then
    chown -R ldap:ldap $configdir
    chown -R ldap:ldap $datadir
    echo -e "$RED Config folder and data folder are not empty.$NC"
    echo -e "$RED Starting OpenLDAP with existing configuration.$NC"
    systemctl start slapd
    systemctl enable slapd
    STATUS="$(systemctl is-active slapd)"
    if [ "${STATUS}" = "active" ]; then
        echo -e "$GREEN slapd is started with existing configuration.$NC"
        exit 0
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
    
    chown -R ldap:ldap $configdir
    chown -R ldap:ldap $datadir

    systemctl start slapd 
    systemctl enable slapd
    STATUS="$(systemctl is-active slapd)"
    if [ "${STATUS}" = "active" ]; then
        echo -e "$GREEN slapd is started with clean installation.$NC"
    else
        echo -e "$RED Something went wrong. Cannot start slapd.$NC"
        echo -e "$YELLOW Press Enter to exit.$NC"
        read -p ""
        exit 1
    fi 


    echo -e "$GREEN Configuring OpenLDAP...$NC"
    HASHED_PASS=`slappasswd -h {SSHA} -s $LDAP_PASS`

    echo -e "$GREEN Setting up OpenLDAP database.$NC"
    /usr/bin/cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown -R ldap:ldap $datadir

    echo -e "$GREEN Building chrootpw.ldif$NC"    
    sed -i -e "s@olcRootPW:.*@olcRootPW: $HASHED_PASS@g" /chrootpw.ldif

    echo -e "$GREEN Import chrootpw.ldif to OpenLDAP.$NC"
    ldapadd -Y EXTERNAL -H ldapi:/// -f /chrootpw.ldif

    echo -e "$GREEN Import basic schema to OpenLDAP.$NC"
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

    echo -e "$GREEN Building chdomain.ldif$NC"
    sed -i -e "s@olcRootPW:.*@olcRootPW: $HASHED_PASS@g" /chdomain.ldif
    ldapmodify -Y EXTERNAL -H ldapi:/// -f /chdomain.ldif

    echo -e "$GREEN Building basedomain.ldif$NC"
    ldapadd -x -w $LDAP_PASS -D "cn=$ADMIN_LDAP,dc=$DC1,dc=$DC2" -f /basedomain.ldif

    # echo -e "$GREEN Building db.ldif$NC"
    # sed -i -e "s@olcRootPW:.*@olcRootPW: $HASHED_PASS@g" /db.ldif
    # ldapmodify -Y EXTERNAL -H ldapi:/// -f /db.ldif
    
    # echo -e "$GREEN Building monitor.ldif$NC"
    # ldapmodify -Y EXTERNAL -H ldapi:/// -f /monitor.ldif

    echo -e "$GREEN Generating CA and private key.$NC"
    /gen_ssl.sh

    echo -e "$GREEN Configuring OpenLDAP to use LDAPS.$NC"
    ldapmodify -Y EXTERNAL -H ldapi:/// -f /mod_ssl.ldif
    
    echo -e "$GREEN Modifying /etc/sysconfig/slapd to support LDAPS.$NC"
    sed -i -e "s@SLAPD_URLS:.*@SLAPD_URLS=\"ldapi:\/\/\/ ldap:\/\/\/ ldaps:\/\/\/\"@g" /etc/sysconfig/slapd

    echo -e "$GREEN Add syncprov module for replication.$NC"
    ldapadd -Y EXTERNAL -H ldapi:/// -f /mod_syncprov.ldif
    echo -e "$GREEN syncprov module is added.$NC"

    echo -e "$GREEN Allowed module syncprov on DB LDAP.$NC"
    ldapadd -Y EXTERNAL -H ldapi:/// -f /syncprov.ldif
    echo -e "$GREEN module syncprov is allowed on DB LDAP.$NC"

    systemctl restart slapd
    STATUS="$(systemctl is-active slapd)"
    if [ "${STATUS}" = "active" ]; then
        echo -e "$GREEN slapd is started with master configuration.$NC"
    else
        echo -e "$RED Something went wrong with master configuration.$NC"
        echo -e "$YELLOW Press Enter to exit.$NC"
        read -p ""
        exit 1
    fi  
fi

exit 0

