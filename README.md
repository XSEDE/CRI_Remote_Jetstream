WIP: modify existing basic slurm installation (from OpenHPC rpm) to have the option of a remote
queue via Openstack (Jetstream).

compute_build_base_img.yml  - playbook to build compute image - FOR EVENTUAL CREATE-DESTROY CHANGE.
 - TODO:
   - work out framework for updating snapshots

config_computes.yml - playbook to config compute nodes after create
 - TODO: 
   - add SSHFS stuff
   -- from headnode, create ssh -R tunnel to compute
   -- on compute, add sshfs entry to fstab
   -- NO FIREWALL STUFF NEEDED (hopefully)
   - how to get remote node public IPs?
   - test

create_nodes.yml  - playbook to create remote nodes
 - TODO:
   - add prevent-updates.ci
   - should firewall stuff go here?

destroy_nodes.yml - playbook to destroy remote nodes
 - TODO: 
   - test

install.yml - playbook to install the slurm remote queue, and create JS network infra
 - TODO:

Uses inventory/js_inventory.py as a dynamic inventory source
 - can this be streamlined to limit the # of openstack calls that get made?
