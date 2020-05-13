-------- HOST 1 --------(MASTER) 
0) Input the information in the file config.txt

1) Build OpenLDAP Docker image:
docker build -t openldap1 .

2) Run new docker as OpenLDAP master:
docker run -itd --name ldapmaster -v `pwd`/data/openldap:/etc/openldap \
-v `pwd`/data/ldap:/var/lib/ldap -p 389:389 -p 636:636 openldap1

3) Configure OpenLDAP as master
docker exec -it -u 0 ldapmaster /ldap_master.sh

4) start OpenLDAP
docker exec -it -u 0 ldapmaster /start.sh

5) stop OpenLDAP
docker exec -it -u 0 ldapmaster /stop.sh

6) restart OpenLDAP
docker exec -it -u 0 ldapmaster /restart.sh

-------- HOST 2 --------(SLAVE)
0) Input the information in the file config.txt

1) Transfer Docker image to HOST 2 or build a new one:
docker build -t openldap1 .

2) Run another docker as OpenLDAP slave:
docker run -itd --name ldapslave -v `pwd`/data/openldap:/etc/openldap \
-v `pwd`/data/ldap:/var/lib/ldap -p 389:389 -p 636:636 openldap1

3) Configure OpenLDAP as slave:
docker exec -it -u 0 ldapslave /ldap_slave.sh

4) start OpenLDAP
docker exec -it -u 0 ldapslave /start.sh

5) stop OpenLDAP
docker exec -it -u 0 ldapslave /stop.sh

6) restart OpenLDAP
docker exec -it -u 0 ldapslave /restart.sh