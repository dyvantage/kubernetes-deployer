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

# lookup address for load-balancer (that fron-ends master nodes)
if [ -n "${master_lb_ip}" ]; then
	stdout "INFO: using override value for master_lb_ip (user-defined value = ${master_lb_ip})"
else
	master_lb_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_load_balancer_dns_name | jq -r '.')
fi

# setup worker nodes
stdout "[Configuring Local Kubeconfig for admin]"
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${pkg_cert_dir}/ca.pem \
    --embed-certs=true \
    --server=https://${master_lb_ip}:6443 | debug

  kubectl config set-credentials admin \
    --client-certificate=${pkg_cert_dir}/admin.pem \
    --client-key=${pkg_cert_dir}/admin-key.pem | debug

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin | debug

  kubectl config use-context kubernetes-the-hard-way | debug

# validate worker nodes have successfully joined cluster
stdout "[Validating Cluster]"
stdout "---- componentstatuses ----"
kubectl get componentstatuses | debug
stdout "---- nodes ----"
kubectl get nodes | debug

exit 0
