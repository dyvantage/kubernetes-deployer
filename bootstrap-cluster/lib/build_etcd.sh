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
debug "Logger Started: ${log_file}"

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

# Download etcd
stdout "[Downloading etcd]"
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : downloading etcd"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")
	remote_cmd="wget -q --https-only 'https://github.com/etcd-io/etcd/releases/download/v3.4.10/etcd-v3.4.10-linux-amd64.tar.gz'"
	remote_path="/home/ubuntu/etcd-v3.4.10-linux-amd64.tar.gz"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: copy failed"; fi
done

# Extract etcd
stdout "[Extracting etcd]"
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : extracting etcd"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")
	remote_cmd="tar -xf etcd-v3.4.10-linux-amd64.tar.gz && sudo mv etcd-v3.4.10-linux-amd64/etcd* /usr/local/bin/"
	remote_path="/usr/local/bin/etcdctl"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: extraction failed"; fi
done

# Configure TLS
stdout "[Configuring TLS]"
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : configuring TLS"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")
	remote_cmd="sudo mkdir -p /etc/etcd /var/lib/etcd && sudo chmod 700 /var/lib/etcd && sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/"
	remote_path="/etc/etcd/kubernetes-key.pem"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: TLS configuration failed"; fi
done

# Build List of Cluster Members
stdout "[Building Cluster Membership List]"
cluster_members=""
for instance in $(get_master_nodes); do
	private_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_private_ips | jq -r ".\"${instance}\"")
	member_info="${instance}=https:\/\/${private_ip}:2380"
	stdout "--> ${instance} : ${member_info}"
	if [ -z "${cluster_members}" ]; then
		cluster_members="${member_info}"
	else
		cluster_members="${cluster_members},${member_info}"
	fi
done

# Parameterize/Push systemd template
stdout "[Parameterizing/Copying systemd Template for etcd Service]"
system_tpl=${pkg_tpl_dir}/etcd.service.tpl
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : parameterizing etcd.service template"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")
	private_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_private_ips | jq -r ".\"${instance}\"")
	tmpfile=/tmp/etcd.service.${instance}.tpl
	cp -f ${system_tpl} ${tmpfile}
	sed -i "s/{{INTERNAL_IP}}/${private_ip}/g" ${tmpfile}
	sed -i "s/{{ETCD_NAME}}/${instance}/g" ${tmpfile}
	sed -i "s/{{ETCD_CLUSTER_MEMBERS}}/${cluster_members}/g" ${tmpfile}

	# copy to node
	stdout "--> ${instance} : copying parameterized template to host"
	scp_sudo ${service_account_master} ${public_ip} ${private_key_master} ${tmpfile} /etc/systemd/system/etcd.service
done

# Configure etcd service
stdout "[Configuring etcd Service (systemd)]"
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : configuring etcd service"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")
	remote_cmd="sudo systemctl daemon-reload && sudo systemctl enable etcd && sudo systemctl stop etcd && sudo systemctl start etcd &"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
done

# Validate etcd cluster 
stdout "[Validating etcd Cluster]"
sleep 30
remote_cmd="sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem"
ssh_exec ${service_account_master} ${master_lb_ip} ${private_key_master} "${remote_cmd}" | debug

exit 0
