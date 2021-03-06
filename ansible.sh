#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -z ${1} ]
then
	echo "Usage: ${0} <Ansible Playbook>"
	echo "======================================"
	pushd ${DIR}/ansible >/dev/null && ls -1 *.yml && popd >/dev/null
	exit 1
fi
ANSIBLE_HOST_KEY_CHECKING=false ansible -i ${DIR}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n77
ANSIBLE_HOST_KEY_CHECKING=false ansible -i ${DIR}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n91
ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u root -i ${DIR}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ${DIR}/ansible/${1}
