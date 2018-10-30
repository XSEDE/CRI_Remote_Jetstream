#!/bin/bash

log_loc=/var/log/slurm/slurm_elastic.log

#Get hostlist from slurm, add ", ", remove last ",", and wrap in ['s for ansible list format
ansible_hosts="[ \"$(scontrol show hostnames $1 | tr '\n' ',' | sed 's/,$//' | sed 's/,/\", \"/g')\" ]"

echo "$(date) Resuming $ansible_hosts :" >> $log_loc

ansible-playbook -e "{ compute_instance_list: ${ansible_hosts} }" /etc/slurm/create_nodes.yml 2>&1 >> $log_loc

