#!/bin/bash

#CONFIG
IF_CFG='/etc/network/interfaces'
RESOLV='/etc/resolv.conf1'
HOSTNAME='vm1'

#IMPORT STRING
source ./vm1.config
CUR_IP=$(ifconfig $EXTERNAL_IF | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')

##### SYS CONFIG ###############################################################################
hostname $HOSTNAME
echo $CUR_IP $HOSTNAME > /etc/hosts
echo 'nameserver 8.8.8.8' >> $RESOLV
echo 'nameserver 8.8.4.4' >> $RESOLV
################################################################################################

###### CONFIG ETHER INTERFACE ##################################################################
#MAIN
echo '# Config interfaces' > $IF_CFG
echo 'source /etc/network/interfaces.d/*' >> $IF_CFG
echo  >> $IF_CFG
echo '# The loopback network interface' >> $IF_CFG
echo 'auto lo' >> $IF_CFG
echo 'iface lo inet loopback' >> $IF_CFG
echo  >> $IF_CFG

#EXTERNAL
echo '# External interface' >> $IF_CFG
if [ "$EXT_IP" = "DHCP" ]; then
#IF DHCP
echo "auto  $EXTERNAL_IF" >> $IF_CFG
echo "iface $EXTERNAL_IF inet dhcp" >> $IF_CFG
#IF MAN
else
echo "auto  $EXTERNAL_IF" >> $IF_CFG
echo "iface $EXTERNAL_IF inet static" >> $IF_CFG
echo "address $EXT_IP" >> $IF_CFG
echo "gateway $EXT_GW" >> $IF_CFG
fi
echo >> $IF_CFG

#INTERNAL
echo '# Internal interface' >> $IF_CFG
echo "auto  $INTERNAL_IF" >> $IF_CFG
echo "iface $INTERNAL_IF inet static" >> $IF_CFG
echo "address $INT_IP" >> $IF_CFG
echo  >> $IF_CFG

#INTERNAL VLAN
modprobe 8021q
vconfig add $INTERNAL_IF $VLAN >> /dev/null 2>&1
echo '# Internal interface vlan' >> $IF_CFG
echo "auto  $INTERNAL_IF.$VLAN" >> $IF_CFG
echo "iface $INTERNAL_IF.$VLAN inet static"  >> $IF_CFG
echo "address $VLAN_IP" >> $IF_CFG
echo  >> $IF_CFG
# APLY
systemctl restart networking
#################################################################################################


##### NAT #######################################################################################
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -A INPUT -i lo -j ACCEPT
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -j ACCEPT
iptables -t nat -A POSTROUTING -o $EXTERNAL_IF -j MASQUERADE
iptables -A FORWARD -i $EXTERNAL_IF -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -j REJECT
#################################################################################################

##### NGINX INSTALL##############################################################################
apt update >> /dev/null 2>&1 && apt install nginx -y >> /dev/null 2>&1
#################################################################################################

##### CERT ######################################################################################
#CREATE CONFIG
echo "
[ req ]
default_bits                = 4096
default_keyfile             = privkey.pem
distinguished_name          = req_distinguished_name
req_extensions              = v3_req
 
[ req_distinguished_name ]
countryName                 = Country Name (2 letter code)
countryName_default         = UK
stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = Wales
localityName                = Locality Name (eg, city)
localityName_default        = Cardiff
organizationName            = Organization Name (eg, company)
organizationName_default    = Example UK
commonName                  = Common Name (eg, YOUR name)
commonName_default          = one.test.app.example.net
commonName_max              = 64
 
[ v3_req ]
basicConstraints            = CA:FALSE
keyUsage                    = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName              = @alt_names
 
[alt_names]
IP.1   = $CUR_IP
DNS.1   = $HOSTNAME" > /usr/lib/ssl/openssl-san.cnf 

#GENERATE KEY
openssl genrsa -out /etc/ssl/certs/root-ca.key 4096 >> /dev/null 2>&1
openssl req -x509 -new -key /etc/ssl/certs/root-ca.key -days 365 -out /etc/ssl/certs/root-ca.crt -subj "/C=UA/L=Kharkov/O=DLNet/OU=NOC/CN=dlnet.kharkov.com" >> /dev/null 2>&1
openssl genrsa -out /etc/ssl/certs/web.key 4096 >> /dev/null 2>&1
openssl req -new -key /etc/ssl/certs/web.key -out /etc/ssl/certs/web.csr -config /usr/lib/ssl/openssl-san.cnf -subj "/C=UA/L=Kharkov/O=DLNet/OU=NOC/CN=$HOSTNAME"  >> /dev/null 2>&1
openssl x509 -req -in /etc/ssl/certs/web.csr -CA /etc/ssl/certs/root-ca.crt  -CAkey /etc/ssl/certs/root-ca.key -CAcreateserial -out /etc/ssl/certs/web.crt -days 365 -extensions v3_req -extfile /usr/lib/ssl/openssl-san.cnf >> /dev/null 2>&1
cat /etc/ssl/certs/root-ca.crt >> /etc/ssl/certs/web.crt
############################################################################################

##### NGINX CONFIG #########################################################################
rm -r /etc/nginx/sites-enabled/* >> /dev/null 2>&1
cp /etc/nginx/sites-available/default  /etc/nginx/sites-available/$HOSTNAME

echo '### CONFIG ###' > /etc/nginx/sites-available/$HOSTNAME
echo "
upstream $HOSTNAME {
server $APACHE_VLAN_IP:80;
}

server {
listen  $CUR_IP:$NGINX_PORT ssl $HOSTNAME_server;
server_name $HOSTNAME
ssl on;
ssl_certificate /etc/ssl/certs/web.crt;
ssl_certificate_key /etc/ssl/certs/web.key;

 location / {
            proxy_pass http://$HOSTNAME;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
	}

} " >> /etc/nginx/sites-available/$HOSTNAME

ln -s /etc/nginx/sites-available/$HOSTNAME /etc/nginx/sites-enabled/$HOSTNAME

service nginx restart
