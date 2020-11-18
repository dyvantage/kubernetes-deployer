#!/bin/bash

flags=""

usage() {
	echo "Usage: $(basename $0) [--lb-ip <ip-address> | --help]"
	exit 1
}

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

# timeout loop: wait ${} seconds for Terraform to populate output variable
sleep 10

lib/build_certificates.sh ${flags} && \
lib/build_encryption.sh ${flags} && \
lib/build_kubeconfigs.sh ${flags} && \
lib/build_etcd.sh ${flags} && \
lib/build_control_plane.sh ${flags} && \
lib/build_hosts_file.sh ${flags} && \
lib/build_workers.sh ${flags} && \
lib/build_admin_kubeconfig.sh ${flags} && \
lib/build_dns.sh ${flags}
