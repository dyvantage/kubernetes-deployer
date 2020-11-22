#!/bin/bash

flags=""

usage() {
	echo "Usage: $(basename $0) [--lb-ip <ip-address> | --help]"
	exit 1
}

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
		flags="--lb-ip ${2}"
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

# create tmp directories for artifacts
for i in certs csr kubeconfigs log; do
	if [ ! -r ${i} ]; then
		mkdir ${i}
		if [ $? -ne 0 ]; then
			echo "ERROR: failed to create directory: ${i}"
			exit 0
		fi
	fi
done

# timeout loop: wait for Terraform to populate an output variable
stdout "[Timeout Loop: wait for terraform state update]"
start_time=$(date +%s)
elapsed_time=0
timeout=300
while [ ${elapsed_time} -lt ${timeout} ]; do
        stdout "--> polling (${elapsed_time} seconds elapsed)"
        (cd ${pkg_basedir}/.. && terraform output -json master_private_ips > /dev/null 2>&1)
        if [ $? -eq 0 ]; then
                (cd ${pkg_basedir}/.. && terraform output -json worker_private_ips > /dev/null 2>&1)
                if [ $? -eq 0 ]; then
                        break
                fi
        fi

        # pause before next poll
        sleep 2
        current_time=$(date +%s)
        elapsed_time=$(( current_time - start_time ))
done
if [ ${elapsed_time} -ge ${timeout} ]; then assert "TIMEOUT: waiting for terraform output: master_private_ips"; fi
stdout "Done polling, outputs validated: [master_private_ips,worker_private_ips]"

# run bootstrap scripts
lib/build_certificates.sh ${flags} && \
lib/build_encryption.sh ${flags} && \
lib/build_kubeconfigs.sh ${flags} && \
lib/build_etcd.sh ${flags} && \
lib/build_control_plane.sh ${flags} && \
lib/build_hosts_file.sh ${flags} && \
lib/build_workers.sh ${flags} && \
lib/build_admin_kubeconfig.sh ${flags} && \
lib/build_dns.sh ${flags}
