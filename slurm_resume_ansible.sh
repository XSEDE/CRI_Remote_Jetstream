#!/bin/bash

log_loc=/var/log/slurm/slurm_resume.log

#Get hostlist from slurm, add ", ", remove last ",", and wrap in ['s for ansible list format
ansible_hosts="[ \"$(scontrol show hostnames $1 | tr '\n' ',' | sed 's/,$//' | sed 's/,/\", \"/g')\" ]"

echo "$(date) Resuming $ansible_hosts :" >> $log_loc

count=1
declare -i count

ansible_result=1

until [[ "${ansible_result}" = 0 ]] || [[ $count -ge 4 ]]; 
do
  echo "$(date) Playbook run $count:" >> $log_loc
  ansible-playbook -e "{ compute_instance_list: ${ansible_hosts} }" /etc/slurm/computes.yml 2>&1 >> $log_loc
  ansible_result=$?
  echo "$(date) ansible_result: $ansible_result" >> $log_loc
  count+=1
done

echo "$(date) Resume finished after $((count-1)) tries" >> $log_loc

