#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in late_start service mode
# More info in the main Magisk thread

. /etc/overture/module.conf

$MODDIR/executable/daemon $MODDIR/executable/overture -c /etc/overture/overture.conf

if [ -n "$LOCALHOST_ALIAS" ];then
iptables -t nat -A OUTPUT     --destination $LOCALHOST_ALIAS -j DNAT --to-destination 127.0.0.1
iptables -t nat -A PREROUTING --destination $LOCALHOST_ALIAS -j DNAT --to-destination 127.0.0.1
fi

if [ "$RUN_DNS_KEEPER" = "true" ];then
$MODDIR/executable/daemon $MODDIR/executable/dns_keeper 127.0.0.1
fi

