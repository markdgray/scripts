#!/bin/bash  -e

OVN_K8S=~/ovn-kubernetes
export KUBECONFIG=${HOME}/admin.conf


function 1_start_kind() {
	pushd $OVN_K8S/contrib
	./kind.sh
	popd
}

function 1_stop_kind() {
	pushd $OVN_K8S/contrib
	./kind.sh --delete --name ovn
	popd
}



function 1_get_pod_names {
	POD_OVNKUBE_MASTER=`kubectl --show-kind=false -n ovn-kubernetes get pods  -l name=ovnkube-master -o name`
	POD_OVNKUBE_MASTER=${POD_OVNKUBE_MASTER:4} #ignore first 4 chars i.e. pod/

	WORKERS=`kubectl -n ovn-kubernete get pods -A -l name=ovnkube-node -o name`

	for WORKER in $WORKERS
	do
		NAME=`kubectl -n ovn-kubernetes get  $WORKER -o jsonpath='{.spec.nodeName}'`
		echo "$WORKER is running on $NAME"

		if [ "$NAME" = "ovn-worker2" ]
		then
			echo "Found ovn-worker2 node"
			POD_OVN_WORKER2=${WORKER:4} #ignore first 4 chars i.e. pod/
		elif [ "$NAME" = "ovn-worker" ]  
		then
			echo "Found ovn-worker node"
			POD_OVN_WORKER=${WORKER:4} #ignore first 4 chars i.e. pod/
		elif [ "$NAME" = "ovn-control-plane" ]
		then
			echo "Found ovn-control-plane node"
			POD_OVN_CONTROL_PLANE=${WORKER:4} #ignore first 4 chars i.e. pod/
		else
			echo "ERROR: Unknown worker node"
		fi

	done
}

function 1_ca_init {
	echo "Initializing CA ..."
	kubectl exec -c ovn-northd -n ovn-kubernetes -it $POD_OVNKUBE_MASTER -- ovs-pki init --force
}

function 1_keys_generate {
	echo "Generating keys ..."
	WORKERS=`kubectl -n ovn-kubernete get pods -A -l name=ovnkube-node -o name`

	for WORKER in $WORKERS
	do
      		CN=`kubectl -c ovs-daemons -n ovn-kubernetes exec -it  $WORKER -- ovs-vsctl get Open_vSwitch . external_ids:system-id | sed 's/"//g' | tr -d '\n\r'`
      	
		kubectl  exec -c ovs-daemons -n ovn-kubernetes $WORKER -- ovs-pki req -u $CN --force
	done

			
}

function 1_keys_sign {
	echo "Signing keys ..."
	WORKERS=`kubectl -n ovn-kubernetes get pods -A -l name=ovnkube-node -o name`

	kubectl cp -n ovn-kubernetes $POD_OVNKUBE_MASTER:/var/lib/openvswitch/pki/switchca/cacert.pem /tmp/cacert.pem

	for WORKER in $WORKERS
        do
      		CN=`kubectl -c ovs-daemons -n ovn-kubernetes exec -it  $WORKER -- ovs-vsctl get Open_vSwitch . external_ids:system-id | sed 's/"//g' | tr -d '\n\r'`
		kubectl cp -c ovs-daemons -n ovn-kubernetes ${WORKER:4}:/root/$CN-req.pem /tmp/$CN-req.pem
		kubectl cp -c ovn-northd -n ovn-kubernetes /tmp/$CN-req.pem $POD_OVNKUBE_MASTER:/root/$CN-req.pem
		kubectl exec -c ovn-northd -n ovn-kubernetes $POD_OVNKUBE_MASTER -- ovs-pki -b sign $CN switch --force
		kubectl cp -c ovn-northd -n ovn-kubernetes $POD_OVNKUBE_MASTER:/root/$CN-cert.pem /tmp/$CN-cert.pem
		kubectl cp -c ovs-daemons -n ovn-kubernetes /tmp/$CN-cert.pem ${WORKER:4}:/root/$CN-cert.pem
		kubectl cp -c ovs-daemons -n ovn-kubernetes /tmp/cacert.pem ${WORKER:4}:/root/cacert.pem

        done


}

function 1_keys_install {
	WORKERS=`kubectl -n ovn-kubernetes get pods -A -l name=ovnkube-node -o name`

	for WORKER in $WORKERS
	do
      		CN=`kubectl -c ovs-daemons -n ovn-kubernetes exec -it  $WORKER -- ovs-vsctl get Open_vSwitch . external_ids:system-id | sed 's/"//g' | tr -d '\n\r'`
		kubectl -n ovn-kubernetes -c ovs-daemons exec -it $WORKER -- mkdir -p /etc/keys
		kubectl -n ovn-kubernetes -c ovs-daemons exec -it $WORKER -- cp /root/$CN-cert.pem /root/$CN-privkey.pem /root/cacert.pem /etc/keys
		kubectl -n ovn-kubernetes -c ovs-daemons exec -it $WORKER -- ovs-vsctl set Open_vSwitch .  other_config:certificate=/etc/keys/$CN-cert.pem other_config:private_key=/etc/keys/$CN-privkey.pem other_config:ca_cert=/etc/keys/cacert.pem
	done
}


function 1_sh_ow {
	kubectl -n ovn-kubernetes exec -it $POD_OVN_WORKER -- /bin/bash
}
function 1_sh_ow2 {
	kubectl -n ovn-kubernetes exec -it $POD_OVN_WORKER2 -- /bin/bash
}
function 1_sh_ocp {
	kubectl -n ovn-kubernetes exec -it $POD_OVN_CONTROL_PLANE -- /bin/bash
}

function 1_ipsec_enable {
	kubectl exec -c ovn-northd -n ovn-kubernetes -it $POD_OVNKUBE_MASTER -- ovn-nbctl set nb_global . ipsec=true	

}

function 1_image_build {
	sudo yum install -y wget
	rm shell-demo.yaml
	wget https://k8s.io/examples/application/shell-demo.yaml
	sed -i "/hostNetwork/d" shell-demo.yaml
	cat shell-demo.yaml | sed "s/shell-demo/shell-demo2/" > shell-demo2.yaml
	echo "  nodeName: ovn-worker" >> shell-demo.yaml
	echo "  nodeName: ovn-worker2" >> shell-demo2.yaml
	kubectl apply -f shell-demo.yaml
	kubectl apply -f shell-demo2.yaml

	kubectl wait --for=condition=Ready pod/shell-demo
	kubectl wait --for=condition=Ready pod/shell-demo2

	kubectl exec shell-demo2 -- apt-get update
	kubectl exec shell-demo2 -- apt-get -y install iputils-ping iproute2 procps
	kubectl exec shell-demo -- apt-get update
	kubectl exec shell-demo -- apt-get -y install iputils-ping iproute2 procps
}

function 1_ping {
	kubectl exec shell-demo -- ping -c 4 `kubectl get pod/shell-demo2 -o jsonpath={.status.podIP}`
}

function 1_fw_install {
	sudo iptables -A INPUT -p udp --dport 5000 -j ACCEPT
	sudo iptables -A INPUT -p esp -j ACCEPT
}

function 1_tcpdump {
	IP1=`kubectl get pod/shell-demo2 -o jsonpath={.status.hostIP}`
	IP2=`kubectl get pod/shell-demo -o jsonpath={.status.hostIP}`
	sudo tcpdump -vnni `brctl show | grep ^br- | awk '{print $1}'` "host $IP1 and host $IP2"

}

function 1_all {

	1_ca_init

	1_keys_generate
		
	1_keys_sign

	1_keys_install

	1_ipsec_enable

	1_image_build
}

1_get_pod_names
