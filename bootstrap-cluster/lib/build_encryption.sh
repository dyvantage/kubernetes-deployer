#!/bin/bash

master_lb_ip=""

usage() {
	echo "Usage: $(basename $0) [--lb-ip <ip-address> | --help]"
	exit 1
}

## main

# source globals
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

# generate unique encryption key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# initialize path to encryption config
encryption_config_file=${pkg_cert_dir}/encryption-config.yaml

# build config
stdout "[Initializing Encryption]"
stdout "--> parameterizing encryption-config.yaml config template"
cat > ${encryption_config_file} <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

# copy config to masters
stdout "[Distributing Encryption Metadata to Master Nodes]"
for instance in $(get_master_nodes); do
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json master_public_ips | jq -r ".\"${instance}\"")

	# copy config to master node
	local_path=${encryption_config_file}
	remote_path=/home/ubuntu/$(basename ${encryption_config_file})
	stdout "--> ${instance} : copying $(basename ${local_path})"
	scp_exec ${service_account_master} ${public_ip} ${private_key_master} ${local_path} ${remote_path}
	copy_status=$(ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "if [ -r ${remote_path} ]; then echo '0'; else echo '1'; fi")
done

exit 0
