[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name {{ETCD_NAME}} \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --logger=zap \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://{{INTERNAL_IP}}:2380 \
  --listen-peer-urls https://{{INTERNAL_IP}}:2380 \
  --listen-client-urls https://{{INTERNAL_IP}}:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://{{INTERNAL_IP}}:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster {{ETCD_CLUSTER_MEMBERS}} \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
