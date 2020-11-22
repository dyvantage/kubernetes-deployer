#!/bin/bash

master_lb_ip=""

usage() {
	echo "Usage: $(basename $0) [--lb-ip <ip-address> | --help]"
	exit 1
}

## main

# glabal settings
source globals

# Initialize Logger
: "${debug_flag:=2}"
: "${log_file:=${pkg_basedir}/log/${pkg_name}.log}"
source lib/logger.sh
init_log_file
debug "Sub-Logger Started: $(basename $0)"

# validate commandline
while [ $# -gt 0 ]; do
	case ${1} in
	--lb-ip)
		if [ $# -lt 2 ]; then usage; fi
		master_lb_ip=${2}
		shift
		;;
	--help|-h)
		usage
		;;
	*)
		usage
		;;
	esac
	shift
done

# initialize host entry
declare -a etc_hosts_lines
hosts_idx=0
etc_hosts_lines[((hosts_idx++))]=""
etc_hosts_lines[((hosts_idx++))]="# added by INSTALL_CONTROL_PLANE.sh"

# setup worker nodes
stdout "[Configuring Hosts File (for inter-cluster lookups without DNS hostnames)]"
stdout "--> getting master nodes"
for instance in $(get_master_nodes); do
	private_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_private_ips | jq -r ".\"${instance}\"")
	etc_hosts_lines[((hosts_idx++))]="${private_ip} ${instance}"
done

stdout "--> getting worker nodes"
for instance in $(get_worker_nodes); do
	private_ip=$(cd ${pkg_basedir}/.. && terraform output -json worker_private_ips | jq -r ".\"${instance}\"")
	etc_hosts_lines[((hosts_idx++))]="${private_ip} ${instance}"
done

# initialize hosts template
host_file=${pkg_tpl_dir}/hosts.tpl
if [ -r ${host_file} ]; then
	rm -f ${host_file} && touch ${host_file}
	if [ $? -ne 0 ]; then assert "ERROR: failed to initialize empty file: ${host_file}"; fi
fi

debug "[Host Entries to append to /etc/hosts on all nodes]"
for hosts_entry in "${etc_hosts_lines[@]}"; do
	debug "${hosts_entry}"
	echo "${hosts_entry}" >> ${host_file}
done

# Update /etc/hosts on Nodes
stdout "[Updating /etc/hosts on Nodes]"
for instance in $(get_worker_nodes); do
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json worker_public_ips | jq -r ".\"${instance}\"")

	# update hosts file
	local_path=${host_file}
	remote_path=/tmp/hosts.tpl
	stdout "--> ${instance} : updating /etc/hosts"
	scp_exec ${service_account_worker} ${public_ip} ${private_key_worker} ${local_path} ${remote_path}
	copy_status=$(ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: copy failed"; fi

	remote_cmd="cat ${remote_path} | sudo tee -a /etc/hosts"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"
done

for instance in $(get_master_nodes); do
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# update hosts file
	local_path=${host_file}
	remote_path=/tmp/hosts.tpl
	stdout "--> ${instance} : updating /etc/hosts"
	scp_exec ${service_account_master} ${public_ip} ${private_key_master} ${local_path} ${remote_path}
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: copy failed"; fi

	remote_cmd="cat ${remote_path} | sudo tee -a /etc/hosts"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
done

exit 0
