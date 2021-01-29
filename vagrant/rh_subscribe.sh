#!/bin/bash

vagrant ssh $1 -c "sudo subscription-manager register --username=magray@redhat.com"
vagrant ssh $1 -c "sudo subscription-manager attach --auto"
