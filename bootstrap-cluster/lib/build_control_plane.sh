#!/bin/bash

master_lb_ip=""

usage() {
	echo "Usage: $(basename $0) [[--lb-ip <ip-address> | --help]"
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

# Download Kubernetes Contoller Binaries
stdout "[Downloading Kubernetes Contoller Binaries]"
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : downloading kubernetes"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# download
	remote_cmd="sudo mkdir -p /etc/kubernetes/config && \
		wget -q --https-only \
		'https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kube-apiserver' \
		'https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kube-controller-manager' \
		'https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kube-scheduler' \
		'https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kubectl'"
	remote_path="/home/ubuntu/kube-apiserver"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: download failed"; fi

	# install
	stdout "--> ${instance} : installing binaries"
	remote_cmd="chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl && \
		sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/"
	remote_path="/usr/local/bin/kube-apiserver"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: installation failed"; fi

	# configuring
	stdout "--> ${instance} : configuring tls and encryption"
	remote_cmd="sudo mkdir -p /var/lib/kubernetes/ && \
		    sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
		    service-account-key.pem service-account.pem \
		    encryption-config.yaml /var/lib/kubernetes/"
	remote_path="/var/lib/kubernetes/ca.pem"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: configuration failed"; fi
done

# Build List of Cluster Members
stdout "[Building Cluster Membership List]"
cluster_members=""
for instance in $(get_master_nodes); do
	private_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_private_ips | jq -r ".\"${instance}\"")
	member_info="https:\/\/${private_ip}:2379"
	stdout "--> ${instance} : ${member_info}"
	if [ -z "${cluster_members}" ]; then
		cluster_members="${member_info}"
	else
		cluster_members="${cluster_members},${member_info}"
	fi
done

# Parameterize/Push systemd template
stdout "[Parameterizing/Copying kube-apiserver.service Service (systemd)]"
system_tpl=${pkg_tpl_dir}/kube-apiserver.service.tpl
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : parameterizing kube-apiserver.service template"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")
	tmpfile=/tmp/kube-apiserver.service.${instance}.tpl
	cp -f ${system_tpl} ${tmpfile}
	sed -i "s/{{INTERNAL_IP}}/${public_ip}/g" ${tmpfile}
	sed -i "s/{{ETCD_CLUSTER_MEMBERS}}/${cluster_members}/g" ${tmpfile}

	# copy file to node
	stdout "--> ${instance} : copying systemd template to host"
	debug "[Systemd Template: kube-apiserver.service]"
	debug "$(cat ${tmpfile})"
	scp_sudo ${service_account_master} ${public_ip} ${private_key_master} ${tmpfile} /etc/systemd/system/kube-apiserver.service
done

# Configure the Kubernetes Controller Manager
stdout "[Copying kube-controller-manager.service Service (systemd)]"
system_tpl=${pkg_tpl_dir}/kube-controller-manager.service
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : configuring kube-controller-manager"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# configure
	remote_cmd="sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/"
	remote_path="/var/lib/kubernetes/kube-controller-manager.kubeconfig"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: configuration failed"; fi

	# copy file to node
	stdout "--> ${instance} : copying systemd template to host"
	debug "[Systemd Template: kube-controller-manager.service]"
	debug "$(cat ${system_tpl})"
	scp_sudo ${service_account_master} ${public_ip} ${private_key_master} ${system_tpl} /etc/systemd/system/kube-controller-manager.service
done

# Configure the Kubernetes Scheduler
stdout "[Configuring the Kubernetes Scheduler]"
system_tpl=${pkg_tpl_dir}/kube-scheduler.service
kube_scheduler_tpl=${pkg_tpl_dir}/kube-scheduler.yaml
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : configuring kube-scheduler"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# configure
	remote_cmd="sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/"
	remote_path="/var/lib/kubernetes/kube-scheduler.kubeconfig"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	if [ -n "${copy_status}" -a "copy_status" == "1" ]; then assert "ERROR: configuration failed"; fi

	# copy file to node (kube-scheduler.service)
	stdout "--> ${instance} : copying systemd template to host"
	debug "[Systemd Template: kube-scheduler.service]"
	debug "$(cat ${system_tpl})"
	scp_sudo ${service_account_master} ${public_ip} ${private_key_master} ${system_tpl} /etc/systemd/system/kube-scheduler.service

	# copy file to node (kube-scheduler.yaml)
	stdout "--> ${instance} : copying kube-scheduler.yaml template to host"
	debug "[Scheduler Template: kube-scheduler.yaml]"
	debug "$(cat ${kube_scheduler_tpl})"
	scp_sudo ${service_account_master} ${public_ip} ${private_key_master} ${kube_scheduler_tpl} /etc/kubernetes/config/kube-scheduler.yaml
done

# Start the Controller Services
stdout "[Starting the Controller Services (Kubernetes Control Plane)]"
for instance in $(get_master_nodes); do
	stdout "--> ${instance} : starting controller services"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# configure
	remote_cmd="sudo systemctl daemon-reload && \
		sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler && \
		sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"
done

# pause
stdout "[Validating the Control Plane]"
sleep 30
remote_cmd="kubectl get componentstatuses --kubeconfig admin.kubeconfig"
debug "remote_cmd = ${remote_cmd}"
debug "ssh_exec ${service_account_master} ${master_lb_ip} ${private_key_master}"
ssh_exec ${service_account_master} ${master_lb_ip} ${private_key_master} "${remote_cmd}" | stdout

exit 0
