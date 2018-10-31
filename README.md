#XCRI Remote Slurm Partition Toolkit

This toolkit allows one to configure and existsting SLURM cluster with an extra
partition, that will allow one to run jobs on a particular Jetstream allocation.
This is NOT intended for general extension of campus computing resources, but as
an add-on for researchers on a particular allocation, to run jobs on multiple 
resources.

##Installation

Prior to installing, create a "clouds.yaml" file in this directory, which can by used
by the slurm user to access Jetstream (or your Openstack cloud of choice).

Install ansible, and run "ansible-playbook install.yml" on your headnode. It is also
necessary at this time to give sudo privileges to the slurm user, to enable remote
mounting of the local filesystem on the compute instances via sshfs 
(currently only /export is shared, modify to your own situation!).

install.yml - playbook to install the slurm remote queue, and create JS network infra

##Description

This uses SLURM's built-in cloud abilities to manage remote nodes on Jetstream
(or any Openstack cloud). The slurm_suspend/resume_ansible.sh scripts are run
by the slurm user to bring remote compute nodes up and down as needed.
