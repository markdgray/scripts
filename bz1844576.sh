#!/bin/bash

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Run as root"
    exit
fi

export PATH=/usr/local/share/openvswitch/scripts:$PATH

start() {
	ip netns add left
	ip netns add right
	ip link add center-left type veth peer name left0 netns left
	ip link add center-right type veth peer name right0 netns right
	ip link set center-left up
	ip link set center-right up
	ip -n left link set left0 up
	ip -n left addr add 172.31.110.10/24 dev left0
	ip -n right link set right0 up
	ip -n right addr add 172.31.110.11/24 dev right0


	ovs-ctl start --delete-bridges --no-monitor
	ovs-vsctl add-br br0 
	ovs-vsctl add-port br0 center-right
	ovs-vsctl add-port br0 center-left
}

stop() {
	ovs-ctl stop
	ip link del center-left
	ip link del center-right
	ip netns del left
	ip netns del right

}


test() {
	echo "Numer of netlink sockets is: `lsof -p $(pidof ovs-vswitchd) \
	   |grep -c GENERIC `"
	perf record -e sched:sched_wakeup,irq:softirq_entry -ag &
	sleep 2 
	ip netns exec left arping -I left0 -c 1 172.31.110.11
	sleep 2 
	kill %1
	sleep 2 
	ovs-ofctl del-flows br0
	ip -n left link set left0 netns 1
	ip -n right link set right0 netns 1
	ip link set up right0
	ip link set up left0
	ovs-ofctl add-flow br0 action=controller,center-right
	if [ -f ../network-tools/weed ]; then
		../network-tools/weed -c 100000 -i 1m -d rand -s rand left0 right0
		../network-tools/weed  -d rand -s rand left0 right0
	fi
	ovs-ofctl del-flows br0
	ovs-ofctl add-flow br0 action=NORMAL
	ip link set left0 netns left
	ip link set right0 netns right
	perf script

}

case "$1" in
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
		echo "Usage: $0 {start|stop|restart|status|test}"
esac

