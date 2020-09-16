#!/bin/bash

RED="\033[0;31m"
BLUE="\033[0;34m"
GREEN="\033[0;32m"
NC="\033[0m"
TLD="`dirname ${BASH_SOURCE[0]}`/../"
IP1=`getent hosts $2 | awk '{ print $1}'`
IP2=`getent hosts $3 | awk '{ print $1}'`


run_ip1() {
   echo -e "Running: $BLUE$IP1:$@"
   ssh root@$IP1 $@
   echo -e $NC
}

run_ip2() {
   echo -e "Running: $GREEN$IP2:$@"
   ssh root@$IP2 $@
   echo -e $NC
}

copy_ip1_ip2() {
   scp root@$IP1:$1 root@$IP2:$2 
}

copy_ip2_ip1() {
   scp root@$IP2:$1 root@$IP1:$2 
}

run_both() {
    run_ip1 $@
    run_ip2 $@
}

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Run as root"
    exit
fi

build() {
    run_both dnf install -y python3-openvswitch libreswan openvswitch openvswitch-ipsec patch
    run_both sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    run_both curl https://github.com/lzhecheng/ovs/commit/869b06356e389079861962160e864df609d033e5.patch > ipsec.patch
    run_both patch /usr/share/openvswitch/scripts/ovs-monitor-ipsec < ipsec.patch
    run_both setenforce 0
}

start() {
    run_both systemctl set-environment OVS_RUNDIR=/var/run/openvswitch
    run_both systemctl set-environment OVS_PKGDATADIR=/usr/share/openvswitch 
    run_both systemctl restart openvswitch-ipsec.service
    run_both ovs-vsctl add-br br-ipsec
    run_ip1 ip addr add 192.168.0.1/24 dev br-ipsec
    run_ip2 ip addr add 192.168.0.2/24 dev br-ipsec
    run_both ip link set br-ipsec up
    run_ip1 ovs-pki --force req -u host_1
    run_ip1 ovs-pki --force self-sign host_1
    run_ip1 cp -a host_1-cert.pem host_1-privkey.pem /etc/keys
    run_ip1 ovs-vsctl set Open_vSwitch . other_config:certificate=/etc/keys/host_1-cert.pem other_config:private_key=/etc/keys/host_1-privkey.pem

    
    run_ip2 ovs-pki --force req -u host_2
    run_ip2 ovs-pki --force self-sign host_2
    run_ip2 cp -a host_2-cert.pem host_2-privkey.pem /etc/keys
    run_ip2 ovs-vsctl set Open_vSwitch . other_config:certificate=/etc/keys/host_2-cert.pem other_config:private_key=/etc/keys/host_2-privkey.pem

    copy_ip1_ip2 /etc/keys/host_1-cert.pem /etc/keys
    copy_ip2_ip1 /etc/keys/host_2-cert.pem /etc/keys

    run_ip2 ovs-vsctl add-port br-ipsec tun -- set interface tun type=geneve options:remote_ip=$IP1 options:remote_cert=/etc/keys/host_1-cert.pem
    run_ip1 ovs-vsctl add-port br-ipsec tun -- set interface tun type=geneve options:remote_ip=$IP2 options:remote_cert=/etc/keys/host_2-cert.pem
    run_both systemctl restart openvswitch-ipsec.service
   
}

stop() {
    run_both systemctl set-environment OVS_RUNDIR=/var/run/openvswitch
    run_both systemctl set-environment OVS_PKGDATADIR=/usr/share/openvswitch 
    run_both ip link set br-ipsec down
    run_both ovs-vsctl del-br br-ipsec
    run_both systemctl stop openvswitch-ipsec.service
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

