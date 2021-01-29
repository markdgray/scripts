#!/bin/bash
ansible -i ./.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n77
ansible -i ./.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -m ping n91
ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u root -i ./.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ../ansible/basic-setup.yml
