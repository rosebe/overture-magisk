#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in late_start service mode
# More info in the main Magisk thread

. /etc/overture/module.conf

$MODDIR/executable/daemon $MODDIR/executable/overture -c /etc/overture/overture.conf

if [ -n "$LOCALDNS_ALIAS" ];then
	iptables -t nat -A OUTPUT -p tcp --destination $LOCALDNS_ALIAS --dport 53 -j REDIRECT --to-ports 3753
	iptables -t nat -A OUTPUT -p udp --destination $LOCALDNS_ALIAS --dport 53 -j REDIRECT --to-ports 3753
	iptables -t nat -A PREROUTING -p tcp --destination $LOCALDNS_ALIAS --dport 53 -j REDIRECT --to-ports 3753
	iptables -t nat -A PREROUTING -p udp --destination $LOCALDNS_ALIAS --dport 53 -j REDIRECT --to-ports 3753
	
	if [ "$RUN_DNS_KEEPER" = "true" ];then
		$MODDIR/executable/daemon $MODDIR/executable/dns_keeper $LOCALDNS_ALIAS
	fi
fi


