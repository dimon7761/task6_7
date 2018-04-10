#!/bin/bash
#Dmitriy Litvin 2018

#CONFIG
IF_CFG='/etc/network/interfaces'
RESOLV='/etc/resolv.conf'
HOSTNAME='vm2'

#IMPORT STRING
source $(dirname $0)/vm2.config

###### CONFIG ETHER INTERFACE ##################################################################
#LO
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
address $INTERNAL_IP
gateway $GW_IP
dns-nameservers 8.8.8.8
dns-nameservers 8.8.4.4
" >> $IF_CFG

#INTERNAL VLAN
echo '# Internal interface vlan' >> $IF_CFG
echo "auto $INTERNAL_IF.$VLAN
iface $INTERNAL_IF.$VLAN inet static
address $APACHE_VLAN_IP
vlan-raw-device $INTERNAL_IF
" >> $IF_CFG

# APLY
systemctl restart networking

###### SYS CONFIG #############################################################################
CUR_IP=$(ifconfig $INTERNAL_IF | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
hostname $HOSTNAME
echo $CUR_IP $HOSTNAME > /etc/hosts
################################################################################################

