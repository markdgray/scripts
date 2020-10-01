#!/bin/bash

RED="\033[0;31m"
NC="\033[0m"

TLD="`dirname ${BASH_SOURCE[0]}`/../"

echo ${TLD}

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Run as root"
    exit
fi

export PATH=/usr/local/share/openvswitch/scripts:${TLD}/ovn-fake-multinode:$PATH
echo $PATH
start() {
    pushd ${TLD}/ovn-fake-multinode/
    ovs-ctl start --delete-bridges --no-monitor
    ovn_cluster.sh start
    popd
}

stop() {
    pushd ${TLD}/ovn-fake-multinode/
    ovn_cluster.sh stop
    ovs-ctl stop
    popd
}


test () {
   echo "Placeholder"
}

build() {
    pushd ${TLD}/ovn-fake-multinode/
    OVN_SRC_PATH=${TLD}/ovn OVS_SRC_PATH=${TLD}/ovs ovn_cluster.sh build
    popd
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

