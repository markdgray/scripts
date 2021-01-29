#!/bin/bash
ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u root -i ./.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ../ansible/ovs-ipsec-ca.yml
