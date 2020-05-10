FROM centos:centos7

RUN yum -y update && \
    yum -y install openldap-servers openldap-clients

RUN yum clean all

# Default data + default configuration
RUN mkdir -p /root/tmp/openldap && \
    mkdir -p /root/tmp/ldap 

# Copy default data + default configuration
RUN cp -rfa /etc/openldap/* /root/tmp/openldap && \
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG && \
    cp -rfa /var/lib/ldap/* /root/tmp/ldap
    

# Copy management scripts
COPY script/*.sh /
RUN chmod +x /*.sh

# Copy neccessary files to conigure new OpenLDAP service
COPY template/chrootpw.ldif /
COPY template/chdomain.ldif /
COPY template/basedomain.ldif /

# Copy samba schema to integrate samba to OpenLDAP
COPY template/samba.ldif /
COPY template/samba.schema /

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /*.sh

COPY script/systemctl.py /usr/bin/systemctl
RUN chmod +x /usr/bin/systemctl

EXPOSE 389 636

ENTRYPOINT ["/entrypoint.sh"]