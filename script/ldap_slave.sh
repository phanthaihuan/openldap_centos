#!/bin/bash
set -e
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

configdir="/etc/openldap"
datadir="/var/lib/ldap"

ADMIN_LDAP=""
DC1=""
DC2=""
LDAP_PASS=""
LDAP_MASTER_IP=""
LDAP_MASTER_PORT=""
FQDN=""

function displayHelp() 
{
    echo ""
    echo -e "$BLUE Usage: $0 -mip ldap master ip -mport ldap master port -madmin ldap admin -mpass ldap admin password -mdomain domain name $NC"
    echo -e "$BLUE \t-mip  OpenLDAP Master IP$NC"
    echo -e "$BLUE \t-mport   OpenLDAP Master Port$NC"
    echo -e "$BLUE \t-madmin   OpenLDAP Admin Account$NC"
    echo -e "$BLUE \t-mpass  OpenLDAP Admin Password$NC"
    echo -e "$BLUE \t-mdomain FQDN Domain Name$NC"
    exit 1 # Exit script after printing help
}

function getOpts()
{
    while getopts "mip:mp:ma:mpa:fqdn" opt
    do
        case "$opt" in
            mip ) LDAP_MASTER_IP="$OPTARG" ;;
            mport ) LDAP_MASTER_PORT="$OPTARG" ;;
            madmin ) ADMIN_LDAP="$OPTARG" ;;
            mpass ) LDAP_PASS="$OPTARG" ;;
            mdomain ) FQDN="$OPTARG" ;;
            ? ) displayHelp ;;
        esac
    done

    if [ -z "$LDAP_MASTER_IP" ] || [ -z "$LDAP_MASTER_PORT" ] || [ -z "$ADMIN_LDAP" ] || [ -z "$ADMIN_LDAP" ] || [ -z "$FQDN" ]
    then
        echo -e "${RED} Some of the parameters are empty. Please check.$NC"
        echo -e "${RED} Press Enter to continue.$NC"
        read -p ""
        displayHelp
    else
        DC1=`cat $FQDN | cut -d. -f1`
        DC2=`cat $FQDN | cut -d. -f2`
        exit 0
    fi
}


if [ -n "$(ls -A $configdir)" ] && [ -n "$(ls -A $datadir)" ]; then
    echo -e "$RED Config folder and data folder are not empty.$NC"
    echo -e "$RED Please emtpy these folders before configure slave.$NC"
    echo -e "$YELLOW Press Enter to exit.$NC" 
    read -p ""
    exit 1 
else
    echo -e "$GREEN Config folder and data folder are both empty.$NC"
    echo -e "$GREEN Starting to build OpenLDAP Slave. $NC"
    getOpts
    echo -e "$GREEN ---LDAP Master Domain: ${DC1}.${DC2} $NC"
    echo -e "$GREEN ---LDAP Master IP    : ${LDAP_MASTER_IP} $NC"
    echo -e "$GREEN ---LDAP Master Port  : ${LDAP_MASTER_PORT} $NC"
    echo -e "$GREEN ---LDAP Master Admin : ${ADMIN_LDAP} $NC"
    echo -e "$GREEN ---------------------------------------$NC"
    
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

    echo -e "$GREEN Building Master-Slave Replication$NC"
    sed -i -e "s@provider=ldap://:.*@provider=ldap://$LDAP_MASTER_IP:$LDAP_MASTER_PORT@g" /syncrepl.ldif
    sed -i -e "s@dc=srv.*@dc=${DC1}@g" /syncrepl.ldif
    sed -i -e "s@dc=world.*@dc=${DC2}@g" /syncrepl.ldif
    sed -i -e "s@cn=Manager.*@cn=${ADMIN_LDAP}@g" /syncrepl.ldif

    ldapadd -Y EXTERNAL -H ldapi:/// -f /syncrepl.ldif

    systemctl restart slapd
    STATUS="$(systemctl is-active slapd)"
    if [ "${STATUS}" = "active" ]; then
        echo -e "$GREEN slapd is started with Slave configuration.$NC"
    else
        echo -e "$RED Something went wrong with Slave configuration.$NC"
        echo -e "$YELLOW Press Enter to exit.$NC"
        read -p ""
        exit 1
    fi 

fi

exit 0

