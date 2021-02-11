#!/bin/bash

if [ -z ${1} ]
then
	echo "Usage: ${0} <Ansible Playbook>"
	echo "======================================"
	ls -1 ansible/*.yml
	exit 1
fi
ansible -i ./vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n77
ansible -i ./vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n91
ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u root -i ./vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ./ansible/${1}
