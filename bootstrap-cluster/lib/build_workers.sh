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

# setup worker nodes
stdout "[Bootstrapping the Kubernetes Worker Nodes]"
for instance in $(get_worker_nodes); do

	stdout "--> ${instance} : installing packages (socat conntrack ipset) and disabling swap"
	public_ip=$(cd ${pkg_basedir}/.. && terraform output -json worker_public_ips | jq -r ".\"${instance}\"")

	# install packages
	remote_cmd="sudo apt-get -y install socat conntrack ipset > /dev/null 2>&1 && \
		sudo swapoff -a"
	ssh_exec ${service_account_master} ${public_ip} ${private_key_master} "${remote_cmd}"

	# download binaries
	stdout "--> ${instance} : downloading kubernetes binaries (kubectl, kube-proxy, kubelet, cni-plugins)"
	remote_cmd="wget -q --https-only \
		  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.18.0/crictl-v1.18.0-linux-amd64.tar.gz \
		  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc91/runc.amd64 \
		  https://github.com/containernetworking/plugins/releases/download/v0.8.6/cni-plugins-linux-amd64-v0.8.6.tgz \
		  https://github.com/containerd/containerd/releases/download/v1.3.6/containerd-1.3.6-linux-amd64.tar.gz \
		  https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kubectl \
		  https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kube-proxy \
		  https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kubelet"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"

	# create directory structure
	stdout "--> ${instance} : creating directories"
	remote_cmd="sudo mkdir -p \
		  /etc/cni/net.d \
		  /opt/cni/bin \
		  /var/lib/kubelet \
		  /var/lib/kube-proxy \
		  /var/lib/kubernetes \
		  /var/run/kubernetes"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"

	# install and configure
	stdout "--> ${instance} : installing binaries"
	remote_cmd="if [ ! -r containerd ]; then mkdir containerd; fi && \
		  tar -xf crictl-v1.18.0-linux-amd64.tar.gz && \
		  tar -xf containerd-1.3.6-linux-amd64.tar.gz -C containerd && \
		  sudo tar -xf cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni/bin/ && \
		  sudo mv runc.amd64 runc && \
		  chmod +x crictl kubectl kube-proxy kubelet runc  && \
		  sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/ && \
		  sudo mv containerd/bin/* /bin/"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"

	# Configure CNI Networking
	pod_cidr=$(cd ${pkg_basedir}/.. && terraform output -json worker_pod_cidrs | jq -r ".\"${instance}\"")
	pod_cidr_esc=$(echo "${pod_cidr}" | sed -e 's/\//\\\//g')
	stdout "--> parameterizing cni template (pod_cidr_esc = ${pod_cidr_esc})"
	cni_tpl=${pkg_tpl_dir}/10-bridge.conf.tpl
	tmpfile=/tmp/10-bridge.conf.${instance}.tpl
	cp -f ${cni_tpl} ${tmpfile}
	sed -i "s/{{POD_CIDR}}/${pod_cidr_esc}/g" ${tmpfile}

	# copy file to node
	stdout "--> ${instance} : copying cni template (cnio0) to host"
	debug "[CNI Template: 10-bridge.conf]"
	debug "$(cat ${tmpfile})"
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${tmpfile} /etc/cni/net.d/10-bridge.conf

	# copy file to node
	stdout "--> ${instance} : copying cni template (loopback) to host"
	loopback_tpl=${pkg_tpl_dir}/99-loopback.conf
	debug "[CNI Template: 99-loopback.conf]"
	debug "$(cat ${loopback_tpl})"
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${loopback_tpl} /etc/cni/net.d/99-loopback.conf

	# configure containerd
	stdout "--> ${instance} : creating /etc/containerd/"
	remote_cmd="sudo mkdir -p /etc/containerd/"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"

	# copy file to node
	stdout "--> ${instance} : copying containerd template to host"
	containderd_tpl=${pkg_tpl_dir}/config.toml
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${containderd_tpl} /etc/containerd/config.toml

	# copy file to node
	stdout "--> ${instance} : copying containerd service template (systemd) to host"
	containderd_service_tpl=${pkg_tpl_dir}/containerd.service
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${containderd_service_tpl} /etc/systemd/system/containerd.service

	# configure kubelet tls
	stdout "--> ${instance} : configuring kubelet TLS"
	remote_cmd="sudo mv ${instance}-key.pem ${instance}.pem /var/lib/kubelet/ && \
		  sudo mv ${instance}.kubeconfig /var/lib/kubelet/kubeconfig && \
		  sudo mv ca.pem /var/lib/kubernetes/"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"

	# configure kubelet-config
	stdout "--> parameterizing kubelet-config template"
	kubelet_tpl=${pkg_tpl_dir}/kubelet-config.yaml.tpl
	tmpfile=/tmp/kubelet-config.yaml.${instance}.tpl
	cp -f ${kubelet_tpl} ${tmpfile}
	sed -i "s/{{POD_CIDR}}/${pod_cidr_esc}/g" ${tmpfile}
	sed -i "s/{{HOSTNAME}}/${instance}/g" ${tmpfile}

	# copy kubelet-config to node
	stdout "--> ${instance} : copying kubelet-config template to host"
	debug "[Kubelet Template: kubelet-config.yaml]"
	debug "$(cat ${tmpfile})"
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${tmpfile} /var/lib/kubelet/kubelet-config.yaml

	# parameterize kubelet service
	stdout "--> ${instance} : copying kubelet service template (systemd) to host"
	kubelet_service_tpl=${pkg_tpl_dir}/kubelet.service
	debug "[Systemd Configuration: kubelet.service]"
	debug "$(cat ${kubelet_service_tpl})"
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${kubelet_service_tpl} /etc/systemd/system/kubelet.service

	# Configure the Kubernetes Proxy
	stdout "--> ${instance} : configuring kubelet TLS"
	remote_cmd="sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"

	# copy kubx-proxy config to node
	kube_proxy_config_tpl=${pkg_tpl_dir}/kube-proxy-config.yaml
	debug "[Kube Proxy Configuration: kube-proxy-config.yaml]"
	debug "$(cat ${kube_proxy_config_tpl})"
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${kube_proxy_config_tpl} /var/lib/kube-proxy/kube-proxy-config.yaml

	# copy kube-proxy service to node
	kube_proxy_systemd_config_tpl=${pkg_tpl_dir}/kube-proxy.service
	debug "[Systemd Configuration: kube-proxy.service]"
	debug "$(cat ${kube_proxy_systemd_config_tpl})"
	scp_sudo ${service_account_worker} ${public_ip} ${private_key_worker} ${kube_proxy_systemd_config_tpl} /etc/systemd/system/kube-proxy.service

	# start worker services
	stdout "--> ${instance} : starting worker services..."
	remote_cmd="sudo systemctl daemon-reload && \
		  sudo systemctl enable containerd kubelet kube-proxy && \
		  sudo systemctl start containerd kubelet kube-proxy"
	ssh_exec ${service_account_worker} ${public_ip} ${private_key_worker} "${remote_cmd}"
done

# pause
stdout "[Validating Worker Nodes]"
sleep 10
remote_cmd="kubectl get nodes --kubeconfig admin.kubeconfig"
debug "remote_cmd = ${remote_cmd}"
debug "ssh_exec ${service_account_master} ${master_lb_ip} ${private_key_master}"
ssh_exec ${service_account_master} ${master_lb_ip} ${private_key_master} "${remote_cmd}" | debug

exit 0
