#!/bin/bash

#Assumptions: SLURM ALREADY EXISTS!
#             openrc.sh will exist in this dir?
#             What else? Openstackclient already installed?

if [[ ! -e ./openrc.sh ]]; then
  echo "NO OPENRC FOUND! CREATE ONE, AND TRY AGAIN!"
  exit
fi

#if [[ -z "$1" ]]; then
#  echo "NO SERVER NAME GIVEN! Please re-run with ./headnode_create.sh <server-name>"
#  exit
#fi

#if [[ ! -e ${HOME}/.ssh/id_rsa.pub ]]; then
##This may be temporary... but seems fairly reasonable.
#  echo "NO KEY FOUND IN ${HOME}/.ssh/id_rsa.pub! - please create one and re-run!"  
#  exit
#fi

source ./openrc.sh

# Defining a function here to check for quotas, and exit if this script will cause problems!
# also, storing 'quotas' in a global var, so we're not calling it every single time
quotas=$(openstack quota show)
quota_check () 
{
quota_name=$1
type_name=$2 #the name for a quota and the name for the thing itself are not the same
number_created=$3 #number of the thing that we'll create here.

current_num=$(openstack $type_name list -f value | wc -l)

max_types=$(echo "$quotas" | awk -v quota=$quota_name '$0 ~ quota {print $4}')

#echo "checking quota for $quota_name of $type_name to create $number_created - want $current_num to be less than $max_types"

if [[ "$current_num" -lt "$((max_types + number_created))" ]]; then 
  return 0
fi
return 1
}


quota_check "networks" "network" 1
quota_check "subnets" "subnet" 1
quota_check "routers" "router" 1
quota_check "key-pairs" "keypair" 1
quota_check "instances" "server" 1

# Ensure that the correct private network/router/subnet exists
if [[ -z "$(openstack network list | grep ${OS_USERNAME}-remote-net)" ]]; then
  openstack network create ${OS_USERNAME}-remote-net
  openstack subnet create --network ${OS_USERNAME}-remote-net --subnet-range 10.0.0.0/24 ${OS_USERNAME}-remote-subnet1
fi
##openstack subnet list
if [[ -z "$(openstack router list | grep ${OS_USERNAME}-remote-router)" ]]; then
  openstack router create ${OS_USERNAME}-remote-router
  openstack router add subnet ${OS_USERNAME}-remote-router ${OS_USERNAME}-remote-subnet1
  openstack router set --external-gateway public ${OS_USERNAME}-remote-router
fi
#openstack router show ${OS_USERNAME}-api-router

security_groups=$(openstack security group list -f value)
if [[ ! ("$security_groups" =~ "global-ssh") ]]; then
  openstack security group create --description "ssh \& icmp enabled" global-ssh
  openstack security group rule create --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0 global-ssh
  openstack security group rule create --protocol icmp global-ssh
fi
if [[ ! ("$security_groups" =~ "slurm-internal") ]]; then
  openstack security group create --description "internal group for remote slurm queue" slurm-internal
  openstack security group rule create --protocol tcp --dst-port 1:65535 --remote-ip 10.0.0.0/0 slurm-internal
  openstack security group rule create --protocol icmp slurm-internal
fi

yum -y install ansible bash-completion

pip install python-openstackclient

#This is reasonable
ssh-keygen -b 2048 -t rsa -P "" -f slurm-key

source ./openrc.sh

#TODO: Change to a default name for the remote slurm queue
#Get OS Network name of *this* server, and set as the network for compute-nodes
headnode_os_subnet=$(openstack server show $(hostname | cut -f 1 -d'.') | awk '/addresses/ {print $4}' | cut -f 1 -d'=')
sed -i "s/network_name=.*/network_name=$headnode_os_subnet/" ./slurm_resume.sh

# Deal with files required by slurm - better way to encapsulate this section?

mkdir -p -m 700 /etc/slurm/.ssh

cp slurm-key slurm-key.pub /etc/slurm/.ssh/

#TODO: This isn't necessary on JS... Use Ansible for this remotely?
#Make sure slurm-user will still be valid after the nfs mount happens!
cat slurm-key.pub >> /home/centos/.ssh/authorized_keys

chown -R slurm:slurm /etc/slurm/.ssh

cp /etc/munge/munge.key /etc/slurm/.munge.key

chown slurm:slurm /etc/slurm/.munge.key

#How to generate a working openrc in the cloud-init script for this? Bash vars available?
# Gonna be tough, since openrc requires a password...
cp openrc.sh /etc/slurm/

chown slurm:slurm /etc/slurm/openrc.sh

chmod 400 /etc/slurm/openrc.sh

cp compute_playbook.yml /etc/slurm/

cp prevent-updates.ci /etc/slurm/

chown slurm:slurm /etc/slurm/prevent-updates.ci

#cp slurm-logrotate.conf /etc/logrotate.d/slurm

setfacl -m u:slurm:rw /etc/ansible/hosts
setfacl -m u:slurm:rwx /etc/ansible/

cp slurm_*.sh /usr/local/sbin/

cp cron-node-check.sh /usr/local/sbin/

chown slurm:slurm /usr/local/sbin/slurm_*.sh

chown centos:centos /usr/local/sbin/cron-node-check.sh

echo "#13 */6  *  *  * centos     /usr/local/sbin/cron-node-check.sh" >> /etc/crontab

#"dynamic" hostname adjustment
sed -i "s/ControlMachine=slurm-example/ControlMachine=$(hostname -s)/" ./slurm.conf
#TODO: Insert changes carefully into /etc/slurm/slurm.conf!
#cp slurm.conf /etc/slurm/slurm.conf

cp ansible.cfg /etc/ansible/

cp ssh.cfg /etc/ansible/

cp slurm_test.job ${HOME}

#TODO: Decide how this will be handled...
#create share directory
mkdir -m 777 -p /export

#create export of homedirs and /export
echo -e "/home 10.0.0.0/24(rw,no_root_squash) \n/export 10.0.0.0/24(rw,no_root_squash)" > /etc/exports

#Start required services
systemctl enable nfs-server nfs-lock nfs rpcbind nfs-idmap
systemctl restart slurmctld 
systemctl start nfs-server nfs-lock nfs rpcbind nfs-idmap

echo -e "If you wish to enable an email when node state is drain or down, please uncomment \nthe cron-node-check.sh job in /etc/crontab, and place your email of choice in the 'email_addr' variable \nat the beginning of /usr/local/sbin/cron-node-check.sh"
