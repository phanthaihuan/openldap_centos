#!/bin/sh

set -e
RED='\033[0;31m'
GREEN='\033[1;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'
configdir="/etc/openldap"
datadir="/var/lib/ldap"

if [ -n "$(ls -A $configdir)" ] && [ -n "$(ls -A $datadir)" ]; then
    chown -R ldap:ldap $configdir
    chown -R ldap:ldap $datadir
    echo -e "$RED Config folder and data folder are not empty.$NC"
    echo -e "$RED Starting OpenLDAP with existing configuration.$NC"
    systemctl start slapd &
    systemctl enable slapd
    STATUS="$(systemctl is-active slapd)"
    if [ "${STATUS}" = "active" ]; then
        echo -e "$GREEN slapd is started with existing configuration.$NC"
        /bin/bash
    else
        echo -e "$RED Something went wrong with existing configuration.$NC"
        echo -e "$YELLOW Press Enter to exit.$NC"
        read -p
        exit 1
    fi    
else
    echo -e "$GREEN Config folder and data folder are both empty.$NC"
    echo -e "$GREEN Run suitable script to build master or slave $NC"
    echo -e "$CYAN     [1] docker exec -it -u 0 ldapmaster /ldap_master.sh $NC"
    echo -e "$CYAN     [2] docker exec -it -u 0 ldapslave /ldap_slave.sh $NC"
    echo -e "$YELLOW Press Enter to exit.$NC" 
    read -p ""
    /bin/bash 
fi

exit 0


