#!/bin/bash
#
# Uses an ipset to block access from all Tor Exit Nodes that can access a given port on this machine.
# By default, the port used is SSH's port 22, though you can specify any port you like.
#
# Based on code from @thelinuxchoice
# See: https://github.com/thelinuxchoice/blocktor
#
# Also see: http://mikhailian.mova.org/node/194
#

PORT=22
MYIP=$(curl -s ifconfig.me)
PROGNAME=$(basename "$0")
if [ ! -z "$2" ]; then
    case $2 in
        ''|*[!0-9]*) PORT=22 ;;
        *) PORT=$2 ;;
    esac
fi
IPSETNAME="tor$PORT"

function f_info {
    echo ""
    # echo "Program:       $PROGNAME"
    echo "Port:          $PORT"
    echo "IPSet name:    $IPSETNAME"
    echo "My IP address: $MYIP"
    echo ""
}

function f_checkroot {
    if [[ "$(id -u)" -ne 0 ]]; then
        printf "Run this program as root!\n"
        exit 1
    fi
}


function f_start {
    f_checkroot
    echo ""
    echo "Starting tor-block."
    f_info

    local DEPENDENCIES
    DEPENDENCIES="iptables ipset"
    for PACKAGE in $DEPENDENCIES; do
        COUNT=$(/usr/bin/dpkg -l | grep -i -c "$PACKAGE")
        if [ "$COUNT" -eq "0" ]; then
            echo "'$PACKAGE' isn't installed. To install: sudo apt install '$PACKAGE'"
            echo ""
            exit 1
        fi
    done


    printf "Configuring ipset..."
    /sbin/ipset -q -N "$IPSETNAME" iphash
    /usr/bin/wget -q "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$MYIP&port=$PORT" -O - | /bin/sed '/^#/d' | while read IP
    do
        /sbin/ipset -q -A "$IPSETNAME" "$IP"
    done
    if [ ! -d "/etc/iptables" ]; then
        /bin/mkdir "/etc/iptables"
    fi
    /sbin/ipset -q save -f "/etc/iptables/ipset.rules"
    echo "Done. Saved to /etc/iptables/ipset.rules"



    printf "Configuring iptables..."
    checkiptables=$(/sbin/iptables --list | /bin/grep -o "$IPSETNAME src")
    if [[ $checkiptables == "" ]]; then
        /sbin/iptables -A INPUT -p tcp --dport "$PORT" -m set --match-set "$IPSETNAME" src -j DROP
    fi
    if [ ! -e "/etc/iptables/rules.v4" ]; then
        /usr/bin/touch "/etc/iptables/rules.v4"
    fi
    /sbin/iptables-save > /etc/iptables/rules.v4
    echo "Done. Saved: /etc/iptables/rules.v4"
    echo ""
}


function f_stop {
    f_checkroot
    echo ""
    echo "Stopping $PROGNAME."
    f_info
    /sbin/iptables -D INPUT -p tcp --dport "$PORT" -m set --match-set "$IPSETNAME" src -j DROP
    /sbin/ipset destroy "$IPSETNAME"
    echo "$PROGNAME stopped, rules removed."
    echo ""
}


case "$1" in
    --start) f_start ;;
    --stop) f_stop ;;
    *)
        echo "Usage: sudo $PROGNAME [--start|--stop] <port number>"
        echo "<port number> is optional. Defaults to 22 if not supplied."
        echo ""
        exit 1
esac
