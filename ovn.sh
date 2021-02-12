#!/bin/bash
source vagrant.sh  Vagrantfile.ovs
echo -n "Enter subscription manager password: "
read -s pass
echo
vagrant up
./rh_subscribe.sh n77 ${pass}
./rh_subscribe.sh n91 ${pass}
./ansible.sh basic-setup.yml
./ansible.sh ovs-git.yml
./ansible.sh ovn-git.yml
./ansible.sh ovn-b2b.yml
