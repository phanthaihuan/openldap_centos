Default domain: mydomain.com
Default admin account: ldapadm
Default admin password: admin@ldap

-------- HOST 1 -------- 
1) Build OpenLDAP Docker image:
docker build -t openldap1 .

2) Run new docker as OpenLDAP master:
docker run -it --name ldapmaster -v `pwd`/data/openldap:/etc/openldap \
-v `pwd`/data/ldap:/var/lib/ldap -p 389:389 -p 636:636 openldap1

3) Configure OpenLDAP as master
docker exec -it -u 0 ldapmaster /ldap_master.sh

4) Check OpenLDAP's master configuration
docker exec -it -u 0 ldapmaster -x -H ldap://localhost \
-b "dc=ldap,dc=mydomain,dc=com" \
-D "cn=ldapadm,dc=ldap,dc=mydomain,dc=com" \
-w admin@openldap

-------- HOST 2 -------- 
5) Transfer Docker image to HOST 2 or build a new one:
docker build -t openldap1 .

6) Run another docker as OpenLDAP slave:
docker run -it --name ldapslave -v `pwd`/data/openldap:/etc/openldap \
-v `pwd`/data/ldap:/var/lib/ldap -p 389:389 -p 636:636 openldap1

7) Configure OpenLDAP as slave:
docker exec -it -u 0 ldapslave /ldap_slave.sh <ldap_master_ip> <ldap_master_port>
