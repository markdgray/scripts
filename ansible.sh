#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -z ${1} ]
then
	echo "Usage: ${0} <Ansible Playbook>"
	echo "======================================"
	ls -1 ansible/*.yml
	exit 1
fi
ansible -i ${DIR}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n77
ansible -i ${DIR}/vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n91
ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u root -i ${DIR}/vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ${DIR}/ansible/${1}
