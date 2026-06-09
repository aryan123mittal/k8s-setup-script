#!/bin/bash

set -e

echo "===== Disable Swap ====="

swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "===== Load Kernel Modules ====="

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo "===== Configure Sysctl ====="

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

echo "===== Install Packages ====="

apt update

apt install -y \
curl \
wget \
vim \
git \
gnupg \
ca-certificates \
apt-transport-https \
software-properties-common \
conntrack \
socat \
ebtables \
ethtool \
ufw

echo "===== Configure Firewall ====="

ufw --force enable

ufw allow 22/tcp
ufw allow 10250/tcp
ufw allow 179/tcp
ufw allow 30000:32767/tcp

echo "===== Install Containerd ====="

apt install -y containerd

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

echo "===== Kubernetes Repository ====="

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
| gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
| tee /etc/apt/sources.list.d/kubernetes.list

apt update

echo "===== Install Kubernetes ====="

apt install -y kubelet kubeadm

apt-mark hold kubelet kubeadm

echo ""
echo "========================================="
echo "Run the join command from the master node"
echo "========================================="
