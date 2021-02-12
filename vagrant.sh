#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -z ${1} ]
then
	echo "Usage: source vagrant.sh <Vagrantfile>"
	echo "======================================"
	pushd ${DIR}/vagrant >/dev/null && ls -1 Vagrantfile.* && popd >/dev/null
else
	export VAGRANT_VAGRANTFILE="${1}"
	export VAGRANT_CWD="${DIR}/vagrant"
fi
