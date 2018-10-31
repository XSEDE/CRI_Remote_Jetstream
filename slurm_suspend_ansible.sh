#!/bin/bash

log_loc=/var/log/slurm/slurm_suspend.log

ansible_hosts="[ \"$(scontrol show hostnames $1 | tr '\n' ',' | sed 's/,$//' | sed 's/,/\", \"/g')\" ]"

echo "$(date) Suspending $ansible_hosts :" >> $log_loc

count=0
declare -i count

ansible_result=1

until [[ "${ansible_result}" = 0 ]] || [[ $count -ge 3 ]]; 
do
  ansible-playbook -e "{ compute_instance_list: ${ansible_hosts} }" /etc/slurm/destroy_nodes.yml 2>&1 >> $log_loc
  ansible_result=$?
  count+=1
done

echo "$(date) Suspend finished after $count tries" >> $log_loc

