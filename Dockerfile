FROM centos:centos7

RUN yum -y update && \
    yum -y install openldap-servers openldap-clients openssl && \
    yum clean all

# Default data + default configuration
RUN mkdir -p /root/tmp/openldap && \
    mkdir -p /root/tmp/ldap 

# Copy default data + default configuration
RUN cp -rfa /etc/openldap/* /root/tmp/openldap && \
    cp /usr/share/openldap-servers/DB_CONFIG.example /root/tmp/ldap/DB_CONFIG

# Copy management scripts
COPY script/*.sh /
RUN chmod +x /*.sh

# Copy template files to configure new OpenLDAP service
COPY template/* /

# systemctl replacement script
COPY script/systemctl.py /usr/bin/systemctl
RUN chmod +x /usr/bin/systemctl

CMD /usr/bin/systemctl

EXPOSE 389 636