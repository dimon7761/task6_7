#!/bin/bash
#Dmitriy Litvin 2018

#CONFIG
IF_CFG='/etc/network/interfaces1'
RESOLV='/etc/resolv.conf1'
HOSTNAME='vm2'

#IMPORT STRING
source $(dirname $0)/vm2.config

###### CONFIG ETHER INTERFACE ##################################################################
#LO
echo '# Config interfaces
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback;
' > $IF_CFG


