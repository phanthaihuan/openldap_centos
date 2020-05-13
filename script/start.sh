#!/bin/sh

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

config="/config.txt"
configdir="/etc/openldap"
datadir="/var/lib/ldap"


systemctl start slapd 
STATUS="$(systemctl is-active slapd)"
if [ "${STATUS}" = "active" ]; then
    echo -e "$GREEN slapd is started.$NC"
    exit 0
else
    echo -e "$RED Something went wrong. Cannot start slapd.$NC"
    echo -e "$YELLOW Press Enter to exit.$NC"
    read -p ""
    exit 1
fi 

exit 0