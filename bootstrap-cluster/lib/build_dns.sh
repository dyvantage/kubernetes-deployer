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

# install CoreOS DNS add-on
stdout "[Installing Core-DNS Add-On]"
debug "kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.7.0.yaml"
ssh_output=$(kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.7.0.yaml)
stdout ${ssh_output}

exit 0
