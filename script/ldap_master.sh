#!/bin/bash

set -e
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

config="/config.txt"
configdir="/etc/openldap"
datadir="/var/lib/ldap"

CN_ADMIN=""
LDAP_PASS=""
LDAP_MASTER_IP=""
LDAP_MASTER_PORT=""
FQDN=""
DC1=""
DC2=""
HASHED_PASS=`slappasswd -h {SSHA} -s $LDAP_PASS`

while IFS= read -r line
do
    if [[ "$line" =~ .*"CN_ADMIN".* ]]; then
        CN_ADMIN="`echo "$line" | awk '{print $3}'`"
    fi
    if [[ "$line" =~ .*"LDAP_PASS".* ]]; then
        LDAP_PASS="`echo "$line" | awk '{print $3}'`"
    fi
    if [[ "$line" =~ .*"LDAP_MASTER_IP".* ]]; then
        LDAP_MASTER_IP="`echo "$line" | awk '{print $3}'`"
    fi
    if [[ "$line" =~ .*"LDAP_MASTER_PORT".* ]]; then
        LDAP_MASTER_PORT="`echo "$line" | awk '{print $3}'`"
    fi
    if [[ "$line" =~ .*"FQDN".* ]]; then
        FQDN="`echo "$line" | awk '{print $3}'`"
        DC1=`echo $FQDN | cut -d. -f1` # get DC1=mydomain
        DC2=`echo $FQDN | cut -d. -f2` # get DC2=com
    fi
done < $file 


function build_chrootpw()
{
    echo -e "$GREEN Building chrootpw.ldif$NC"    
    sed -i -e "s@olcRootPW:.*@olcRootPW: $HASHED_PASS@g" /chrootpw.ldif
}

function import_schema() 
{
    echo -e "$GREEN Import basic schema to OpenLDAP.$NC"
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
}

function build_chdomain() 
{
    echo -e "$GREEN Building chdomain.ldif$NC"
    sed -i -e "s@olcRootPW:.*@olcRootPW: $HASHED_PASS@g" /chdomain.ldif
    sed -i -e "s@cn=ldapadm@cn=$CN_ADMIN@g" /chdomain.ldif
    sed -i -e "s@dc=mydomain@cn=$DC1@g" /chdomain.ldif
    sed -i -e "s@dc=com@dc=$DC2@g" /chdomain.ldif
    ldapmodify -Y EXTERNAL -H ldapi:/// -f /chdomain.ldif
}

function build_basedomain() 
{
    echo -e "$GREEN Building basedomain.ldif$NC"
    sed -i -e "s@cn=ldapadm@cn=$CN_ADMIN@g" /basedomain.ldif
    sed -i -e "s@dc=mydomain@cn=$DC1@g" /basedomain.ldif
    sed -i -e "s@dc=com@dc=$DC2@g" /basedomain.ldif
    ldapadd -x -w $LDAP_PASS -D "cn=$CN_ADMIN,dc=$DC1,dc=$DC2" -f /basedomain.ldif
}


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
    
    echo -e "$GREEN Setting up OpenLDAP database.$NC"
    /usr/bin/cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    chown -R ldap:ldap $datadir

    echo -e "$GREEN Building chrootpw.ldif$NC"    
    sed -i -e "s@olcRootPW:.*@olcRootPW: $HASHED_PASS@g" /chrootpw.ldif

    ## Build and import chrootpw.ldif
    build_chrootpw

    ## Import base schema
    import_schema
       
    ## Build and import chdomain.ldif
    build_chdomain

    ## Build and import basedomain.ldif
    build_basedomain
        
    echo -e "$GREEN Import monitor.ldif$NC"
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

