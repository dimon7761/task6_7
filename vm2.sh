#!/bin/bash
#Dmitriy Litvin 2018

####################### CONFIG ################################
IF_CFG='/etc/network/interfaces'
RESOLV='/etc/resolv.conf'
HOSTNAME='vm2'

#IMPORT STRING
source $(dirname $0)/vm2.config

###### CONFIG ETHER INTERFACE ##################################################################
echo '# Config interfaces
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
' > $IF_CFG

#INTERNAL
echo '# Internal interface' >> $IF_CFG
echo "auto $INTERNAL_IF
iface $INTERNAL_IF inet static
address $INT_IP
gateway $GW_IP
dns-nameservers 8.8.8.8
dns-nameservers 8.8.4.4
" >> $IF_CFG
ifconfig $INTERNAL_IF $INT_IP
route del default
route add default $GW_IP
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

#INTERNAL VLAN
echo '# Internal interface vlan' >> $IF_CFG
echo "auto $INTERNAL_IF.$VLAN
iface $INTERNAL_IF.$VLAN inet static
address $APACHE_VLAN_IP
vlan-raw-device $INTERNAL_IF
" >> $IF_CFG

###### SYS CONFIG #############################################################################
CUR_IP=$(ifconfig $INTERNAL_IF | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
APH_IP=$(ifconfig $INTERNAL_IF.$VLAN | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
hostname $HOSTNAME
echo $CUR_IP $HOSTNAME > /etc/hosts
################################################################################################

##### APACHE INSTALL##############################################################################
apt update && apt install apache2 -y
#################################################################################################

##### NGINX CONFIG #########################################################################
rm -r /etc/apache2/sites-enabled/*
cp /etc/apache2/sites-available/000-default.conf  /etc/apache2/sites-available/$HOSTNAME.conf
echo '### CONFIG ###' > /etc/apache2/sites-available/$HOSTNAME.conf
echo "
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" >> /etc/apache2/sites-available/$HOSTNAME.conf

ln -s /etc/apache2/sites-available/$HOSTNAME.conf /etc/apache2/sites-enabled/$HOSTNAME.conf
echo "Listen $APH_IP:80" > /etc/apache2/ports.conf
sed -i "/# Global configuration/a \ServerName $HOSTNAME" /etc/apache2/apache2.conf

echo "###### done ######" && systemctl restart apache2

exit $?
