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

# validate kubectl
which kubectl > /dev/null 2>&1
if [ $? -ne 0 ]; then assert "ERROR: please install kubectl"; fi

# get IP address for load-balancer (that front-ends master nodes)
if [ -n "${master_lb_ip}" ]; then
	stdout "INFO: using override value for master_lb_ip (user-defined value = ${master_lb_ip})"
else
	master_lb_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_load_balancer_dns_name | jq -r '.')
fi

# Generate Kubeconfigs for kublets (worker-specific)
stdout "[Generating Kubeconfigs for kublets]"
for instance in $(get_worker_nodes); do
	stdout "--> ${instance}"
	cmd="kubectl config set-cluster kubernetes-the-hard-way \
		--certificate-authority=${pkg_cert_dir}/ca.pem \
		--embed-certs=true \
		--server=https://${master_lb_ip}:6443 \
		--kubeconfig=${pkg_kubeconfig_dir}/${instance}.kubeconfig"
	debug "${cmd}"
	eval ${cmd} | debug

	cmd="kubectl config set-credentials system:node:${instance} \
		--client-certificate=${pkg_cert_dir}/${instance}.pem \
		--client-key=${pkg_cert_dir}/${instance}-key.pem \
		--embed-certs=true \
		--kubeconfig=${pkg_kubeconfig_dir}/${instance}.kubeconfig"
	debug "${cmd}"
	eval ${cmd} | debug

	cmd="kubectl config set-context default \
		--cluster=kubernetes-the-hard-way \
		--user=system:node:${instance} \
		--kubeconfig=${pkg_kubeconfig_dir}/${instance}.kubeconfig"
	debug "${cmd}"
	eval ${cmd} | debug

	cmd="kubectl config use-context default --kubeconfig=${pkg_kubeconfig_dir}/${instance}.kubeconfig"
	debug "${cmd}"
	eval ${cmd} | debug
done

# Generate Kubeconfigs for kube-proxy
stdout "[Generating Kubeconfigs for kube-proxy]"
cmd="kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=${pkg_cert_dir}/ca.pem \
	--embed-certs=true \
	--server=https://${master_lb_ip}:6443 \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-proxy.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-credentials system:kube-proxy \
	--client-certificate=${pkg_cert_dir}/kube-proxy.pem \
	--client-key=${pkg_cert_dir}/kube-proxy-key.pem \
	--embed-certs=true \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-proxy.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-proxy \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-proxy.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config use-context default --kubeconfig=${pkg_kubeconfig_dir}/kube-proxy.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

# Generate Kubeconfigs for kube-controller-manager
stdout "[Generating Kubeconfigs for kube-controller-manager]"
cmd="kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=${pkg_cert_dir}/ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-controller-manager.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-credentials system:kube-controller-manager \
	--client-certificate=${pkg_cert_dir}/kube-controller-manager.pem \
	--client-key=${pkg_cert_dir}/kube-controller-manager-key.pem \
	--embed-certs=true \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-controller-manager.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-controller-manager \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-controller-manager.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config use-context default --kubeconfig=${pkg_kubeconfig_dir}/kube-controller-manager.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

# Generate Kubeconfigs for kube-scheduler
stdout "[Generating Kubeconfigs for kube-scheduler]"
cmd="kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=${pkg_cert_dir}/ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-scheduler.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-credentials system:kube-scheduler \
	--client-certificate=${pkg_cert_dir}/kube-scheduler.pem \
	--client-key=${pkg_cert_dir}/kube-scheduler-key.pem \
	--embed-certs=true \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-scheduler.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-scheduler \
	--kubeconfig=${pkg_kubeconfig_dir}/kube-scheduler.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config use-context default --kubeconfig=${pkg_kubeconfig_dir}/kube-scheduler.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

# Generate Kubeconfigs for admin
stdout "[Generating Kubeconfigs for admin]"
cmd="kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=${pkg_cert_dir}/ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=${pkg_kubeconfig_dir}/admin.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-credentials admin \
	--client-certificate=${pkg_cert_dir}/admin.pem \
	--client-key=${pkg_cert_dir}/admin-key.pem \
	--embed-certs=true \
	--kubeconfig=${pkg_kubeconfig_dir}/admin.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=admin \
	--kubeconfig=${pkg_kubeconfig_dir}/admin.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

cmd="kubectl config use-context default --kubeconfig=${pkg_kubeconfig_dir}/admin.kubeconfig"
debug "${cmd}"
eval ${cmd} | debug

# Distribute Kubeconfigs to Nodes (using scp)
stdout "[Distributing Kubeconfigs to Nodes]"
for instance in $(get_worker_nodes); do
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json worker_public_ips | jq -r ".\"${instance}\"")

	# copy kubeconfigs
	for kubeconfig in ${instance}.kubeconfig kube-proxy.kubeconfig; do
		local_path=${pkg_kubeconfig_dir}/${kubeconfig}
		remote_path=/home/ubuntu/${kubeconfig}
		stdout "--> ${instance} : copying $(basename ${local_path})"
		scp_exec ${service_account_worker} ${public_ip} ${private_key_worker} ${local_path} ${remote_path}
		copy_status=$(ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	done
done

for instance in $(get_master_nodes); do
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# copy kubeconfig
	for kubeconfig in admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig; do
		local_path=${pkg_kubeconfig_dir}/${kubeconfig}
		remote_path=/home/ubuntu/${kubeconfig}
		stdout "--> ${instance} : copying $(basename ${local_path})"
		scp_exec ${service_account_master} ${public_ip} ${private_key_master} ${local_path} ${remote_path}
		copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	done
done

exit 0
