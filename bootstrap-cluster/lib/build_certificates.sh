#!/bin/bash

master_lb_ip=""

usage() {
	echo "Usage: $(basename $0) [--lb-ip <ip-address> | --help]"
	exit 1
}

create_certificate() {
	if [ $# -lt 6 ]; then return 1; fi
	if [ $# -gt 7 ]; then return 1; fi
	local ca=${1}
	local ca_key=${2}
	local ca_config=${3}
	local ca_target=${4}
	local ca_profile=${5}
	local target=${6}
	local cmd=""

	if [ $# -eq 6 ]; then
		cmd="cfssl gencert \
			-ca=${pkg_basedir}/${ca} \
			-ca-key=${pkg_basedir}/${ca_key} \
			-config=${ca_config} \
			-profile=${ca_profile} \
			${ca_target} | cfssljson -bare ${target}"
		debug "${cmd}"
		eval ${cmd}
	else
		cmd="cfssl gencert \
			-ca=${pkg_basedir}/${ca} \
			-ca-key=${pkg_basedir}/${ca_key} \
			-config=${ca_config} \
			-profile=${ca_profile} \
			-hostname=${7} \
			${ca_target} | cfssljson -bare ${target}"
		debug "${cmd}"
		eval ${cmd}
	fi

	for i in ${target}.csr ${target}-key.pem ${target}.pem; do
		if [ ! -f ${i} ]; then return 1; fi
		debug "moving certificate: ${i} -> certs/${i}"
		mv ${i} certs/${i}
		if [ ! -f certs/${i} ]; then return 1; fi
	done
	return 0
}

build_kubelet_csr() {
	if [ $# -ne 2 ]; then return 1; fi
	local csr=${1}
	local instance_name=${2}

	local csr_tpl=${pkg_tpl_dir}/kubelet-csr.tpl
        local tmpfile=/tmp/kubelet-csr.${instance_name}.tpl
        cp -f ${csr_tpl} ${tmpfile}
        sed -i "s/{{instance_name}}/${instance_name}/g" ${tmpfile}
	cp -f ${tmpfile} ${csr}
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

# validate cfssl
which cfssl > /dev/null 2>&1
if [ $? -ne 0 ]; then assert "PKI tools missing, please install cfssl"; fi

# validate cfssljson
which cfssljson > /dev/null 2>&1
if [ $? -ne 0 ]; then assert "PKI tools missing, please install cfssljson"; fi

# Initialize Template Paths
ca_csr_template=${pkg_tpl_dir}/ca-csr.json
ca_config_template=${pkg_tpl_dir}/ca-config.json
admin_csr_template=${pkg_tpl_dir}/admin-csr.json
kube_controller_mgr_csr_template=${pkg_tpl_dir}/kube-controller-manager-csr.json
kube_proxy_csr_template=${pkg_tpl_dir}/kube-proxy-csr.json
kube_scheduler_csr_template=${pkg_tpl_dir}/kube-scheduler-csr.json

# Initialize Certificate Authority
stdout "[Initializing Certificate Authority]"
target="ca"
debug "Payload for 'cfssl gencert -initca <payload>':"
debug "$(cat ${ca_csr_template})"
cmd="cfssl gencert -initca ${ca_csr_template} | cfssljson -bare ${target}"
debug "${cmd}"
eval ${cmd}
for i in ${target}.csr ${target}-key.pem ${target}.pem; do
	if [ ! -f ${i} ]; then assert "ERROR: certificate file missing: ${i}"; fi
	debug "moving cert: ${i} -> certs/${i}"
	mv ${i} certs/${i}
	if [ ! -f certs/${i} ]; then assert "ERROR: certificate file missing: certs/${i}"; fi
done

# Create Certificates for Kubernetes Services
stdout "[Generating Certificates for Kubernetes Services]"
debug "Payload for 'cfssl gencert -config <payload>':"
debug "$(cat ${admin_csr_template})"
cmd="create_certificate certs/ca.pem certs/ca-key.pem ${ca_config_template} ${admin_csr_template} kubernetes admin"
debug "${cmd}"
eval ${cmd}

# Generate CSR for each kubelet (node specific)
stdout "[Generating Kubelet Certificates]"
loop_cnt=0
for instance in $(get_worker_nodes); do
	# build csr
	stdout "--> ${instance}"
	kubelet_csr_template=${pkg_basedir}/csr/${instance}-csr.json
	build_kubelet_csr ${kubelet_csr_template} ${instance}

	# lookup metadata for certificate
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json worker_public_ips | jq -r ".\"${instance}\"")
	if [ $? -ne 0 ]; then assert "ERROR: failed to get public_ip"; fi
	private_ip=$(cd ${pkg_basedir}/.. && terraform output -json worker_private_ips | jq -r ".\"${instance}\"")
	if [ $? -ne 0 ]; then assert "ERROR: failed to get private_ip"; fi

	# create certificate
	debug "Payload for 'cfssl gencert -config <payload>':"
	debug "$(cat ${kubelet_csr_template})"
	create_certificate certs/ca.pem certs/ca-key.pem ${ca_config_template} ${kubelet_csr_template} kubernetes ${instance} "${instance},${public_ip},${private_ip}"
	((loop_cnt++))
done
if [ ${loop_cnt} -eq 0 ]; then assert "ERROR: failed to process nodes"; fi

# Create Certificates for kube-controller-manager
stdout "[Generating kube-controller-manager Certificate"
debug "Payload for 'cfssl gencert -config <payload>':"
debug "$(cat ${kube_controller_mgr_csr_template})"
create_certificate certs/ca.pem certs/ca-key.pem ${ca_config_template} ${kube_controller_mgr_csr_template} kubernetes kube-controller-manager

# Create Certificates for kube-proxy
stdout "[Generating the kube-proxy Certificate]"
debug "Payload for 'cfssl gencert -config <payload>':"
debug "$(cat ${kube_proxy_csr_template})"
create_certificate certs/ca.pem certs/ca-key.pem ${ca_config_template} ${kube_proxy_csr_template} kubernetes kube-proxy

# Create Certificates for kube-scheduler
stdout "[Generating the kube-scheduler Certificate]"
debug "Payload for 'cfssl gencert -config <payload>':"
debug "$(cat ${kube_scheduler_csr_template})"
create_certificate certs/ca.pem certs/ca-key.pem ${ca_config_template} ${kube_scheduler_csr_template} kubernetes kube-scheduler

# Create API Server Certificate
stdout "[Generate the Kubernetes API Server Certificate]"
if [ -n "${master_lb_ip}" ]; then
	stdout "INFO: using override value for master_lb_ip (user-defined value = ${master_lb_ip})"
else
	master_lb_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_load_balancer_dns_name | jq -r '.')
fi
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local
master_ip_list=""
loop_cnt=0
for instance in $(get_master_nodes); do
	private_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_private_ips | jq -r ".\"${instance}\"")
	if [ -z "${master_ip_list}" ]; then
		master_ip_list="${private_ip}"
	else
		master_ip_list="${master_ip_list},${private_ip}"
	fi
	((loop_cnt++))
done
if [ ${loop_cnt} -eq 0 ]; then assert "ERROR: failed to process nodes"; fi

kubernetes_csr_tpl=${pkg_tpl_dir}/kubernetes-csr.json
host_metadata="10.32.0.1,${master_ip_list},${master_lb_ip},127.0.0.1,${KUBERNETES_HOSTNAMES}"
debug "Payload for 'cfssl gencert -config <payload>':"
debug "$(cat ${kubernetes_csr_tpl})"
debug "Payload for 'cfssl gencert -hostname <payload>':"
debug "${host_metadata}"
create_certificate certs/ca.pem certs/ca-key.pem ${ca_config_template} ${kubernetes_csr_tpl} kubernetes kubernetes "${host_metadata}"

# Create Service Account Keypair
stdout "[Creating Service Account Keypair]"
svc_keypair_tpl=${pkg_tpl_dir}/service-account-csr.json
debug "Payload for 'cfssl gencert -config <payload>':"
debug "$(cat ${svc_keypair_tpl})"
create_certificate certs/ca.pem certs/ca-key.pem ${ca_config_template} ${svc_keypair_tpl} kubernetes service-account

# Distribute Certificates to Nodes (using scp)
stdout "[Distributing Certificates to Nodes]"
loop_cnt=0
for instance in $(get_worker_nodes); do
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json worker_public_ips | jq -r ".\"${instance}\"")

	# copy certs
	for cert in ca.pem ${instance}-key.pem ${instance}.pem; do
		local_path=${pkg_cert_dir}/${cert}
		remote_path=/home/ubuntu/${cert}
		stdout "--> ${instance} : copying/scp $(basename ${local_path})"
		scp_exec ${service_account_worker} ${public_ip} ${private_key_worker} ${local_path} ${remote_path}
		copy_status=$(ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	done
	((loop_cnt++))
done
if [ ${loop_cnt} -eq 0 ]; then assert "ERROR: failed to process nodes"; fi

loop_cnt=0
for instance in $(get_master_nodes); do
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# copy certs
	for cert in ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem; do
		local_path=${pkg_cert_dir}/${cert}
		remote_path=/home/ubuntu/${cert}
		stdout "--> ${instance} : copying/scp $(basename ${local_path})"
		scp_exec ${service_account_master} ${public_ip} ${private_key_master} ${local_path} ${remote_path}
		copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
	done
	((loop_cnt++))
done
if [ ${loop_cnt} -eq 0 ]; then assert "ERROR: failed to process nodes"; fi

exit 0
