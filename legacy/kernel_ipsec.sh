#!/bin/bash

RED="\033[0;31m"
BLUE="\033[0;34m"
GREEN="\033[0;32m"
NC="\033[0m"
TLD="`dirname ${BASH_SOURCE[0]}`/../"
IP1=`getent hosts $2 | awk '{ print $1}'`
IP2=`getent hosts $3 | awk '{ print $1}'`

run_ip1_nc() {
   ssh root@$IP1 "$@"
}
run_ip2_nc() {
   ssh root@$IP2 "$@"
}

run_ip1() {
   echo -e "Running: $BLUE$IP1:$@"
   run_ip1_nc "$@"
   echo -e $NC
}

run_ip2() {
   echo -e "Running: $GREEN$IP2:$@"
   run_ip2_nc "$@"
   echo -e $NC
}

copy_ip1_ip2() {
   scp root@$IP1:$1 root@$IP2:$2 
}

copy_ip2_ip1() {
   scp root@$IP2:$1 root@$IP1:$2 
}

copy_ip1() {
   scp $1 root@$IP1:$2 
}

copy_ip2() {
   scp $1 root@$IP2:$2 
}

copy_both() {
    copy_ip1 $1 $2
    copy_ip2 $1 $2
}

run_both() {
    run_ip1 "$@"
    run_ip2 "$@"
}

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Run as root"
    exit
fi

build() {
    run_both dnf install -y libreswan
    run_both sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    run_both setenforce 0
    run_both "rm -f /etc/ipsec.d/*.db"
    run_both ipsec initnss
    run_both "rm -f /etc/ipsec.d/*.secret"
    run_ip1 ipsec newhostkey --output /etc/ipsec.d/west.secret
    run_ip2 ipsec newhostkey --output /etc/ipsec.d/east.secret
    IP1_CKAID=`run_ip1_nc ipsec showhostkey --dump | awk '{ print  $7 }'`
    IP2_CKAID=`run_ip2_nc ipsec showhostkey --dump | awk '{ print  $7 }'`
    IP1_PUBKEY_LEFT=`run_ip1_nc ipsec showhostkey --left --ckaid $IP1_CKAID`
    IP2_PUBKEY_LEFT=`run_ip2_nc ipsec showhostkey --left --ckaid $IP2_CKAID` 
    IP1_PUBKEY_RIGHT=`run_ip1_nc ipsec showhostkey --right --ckaid $IP1_CKAID`
    IP2_PUBKEY_RIGHT=`run_ip2_nc ipsec showhostkey --right --ckaid $IP2_CKAID` 

    cat<<-EOF > /tmp/ipsec.conf
conn mytunnel-in
    keyingtries=%forever
    type=transport
    auto=route
    ike=aes_gcm256-sha2_256
    esp=aes_gcm256
    ikev2=insist
    leftid=@west
    left=$IP1
    rightid=@east
    right=$IP2
    authby=rsasig
    leftprotoport=udp/6081
    rightprotoport=udp
    # use auto=start when done testing the tunnel
EOF
    cat<<-EOF >> /tmp/ipsec.conf
    ${IP1_PUBKEY_LEFT//	/    }
    ${IP2_PUBKEY_RIGHT//	/    }
EOF
    cat<<-EOF >> /tmp/ipsec.conf
conn mytunnel-out
    keyingtries=%forever
    type=transport
    auto=route
    ike=aes_gcm256-sha2_256
    esp=aes_gcm256
    ikev2=insist
    leftid=@west
    left=$IP1
    rightid=@east
    right=$IP2
    authby=rsasig
    leftprotoport=udp
    rightprotoport=udp/6081
    # use auto=start when done testing the tunnel
EOF
    cat<<-EOF >> /tmp/ipsec.conf
    ${IP1_PUBKEY_LEFT//	/    }
    ${IP2_PUBKEY_RIGHT//	/    }
EOF
    copy_ip1 /tmp/ipsec.conf /etc/ipsec.conf

    cat<<-EOF > /tmp/ipsec.conf
conn mytunnel-in
    keyingtries=%forever
    type=transport
    auto=route
    ike=aes_gcm256-sha2_256
    esp=aes_gcm256
    ikev2=insist
    rightid=@west
    right=$IP1
    leftid=@east
    left=$IP2
    authby=rsasig
    rightprotoport=udp/6081
    leftprotoport=udp
    # use auto=start when done testing the tunnel
EOF
    cat<<-EOF >> /tmp/ipsec.conf
    ${IP1_PUBKEY_RIGHT//	/    }
    ${IP2_PUBKEY_LEFT//	/    }
EOF
    cat<<-EOF >> /tmp/ipsec.conf
conn mytunnel-out
    keyingtries=%forever
    type=transport
    auto=route
    ike=aes_gcm256-sha2_256
    esp=aes_gcm256
    ikev2=insist
    rightid=@west
    right=$IP1
    leftid=@east
    left=$IP2
    authby=rsasig
    rightprotoport=udp
    leftprotoport=udp/6081
    # use auto=start when done testing the tunnel
EOF
    cat<<-EOF >> /tmp/ipsec.conf
    ${IP1_PUBKEY_RIGHT//	/    }
    ${IP2_PUBKEY_LEFT//	/    }
EOF
    copy_ip2 /tmp/ipsec.conf /etc/ipsec.conf
    run_both "echo 'include /etc/ipsec.d/*.secret' > /etc/ipsec.secrets"

    rm -f /tmp/ipsec.conf
}

start() {
    run_both ipsec restart
    run_ip1 ip link add tun type geneve id 1000 remote $IP2
    run_ip2 ip link add tun type geneve id 1000 remote $IP1
    run_ip1 ip addr add 192.168.0.1/24 dev tun
    run_ip2 ip addr add 192.168.0.2/24 dev tun
    run_both ip link set tun up
}

stop() {
    run_both ip link del tun
}

test() {
    run_ip1 ping 192.168.0.2
    run_ip2 ping -c 4 192.168.0.1


}

case "$1" in
    build)
        build
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status
        ;;
    test)
        test
        ;;
    *)
        echo "Usage: $0 {build|start|stop|restart|status|test}"
esac

