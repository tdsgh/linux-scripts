#!/bin/bash
# This script installs a Kubernetes tools.
# Author: Dmitry
# Date: 2025-04-05
# Last changes: 2025-04-05
# Usage: ./k8s-kubetools.sh

# set -euo pipefail

if [ ! -d /etc/apt/keyrings ]; then
    echo "No /etc/apt/keyrings directory... Creating it."
    mkdir -p -m 755 /etc/apt/keyrings
fi

echo "Fetching the latest stable release of kubernetes..."
K8S_VERSION=$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
if [[ -z "$K8S_VERSION" ]]; then
    echo "Failed to fetch the latest kubernetes version."
    exit 1
fi
K8S_VERSION=${K8S_VERSION%.*}
echo "Kubernetes version: $K8S_VERSION"

curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

sleep 3

echo
echo "Updating apt and installing kubernetes tools..."
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
echo "Check if swap is disabled after reboot..."
echo "If not, please disable it manually by masking swap unit:"
echo "systemctl mask <UNIT>"
echo "UNIT can be found by running:"
echo "systemctl list-units --type swap"

echo
echo "Set CRI socket for containerd to /run/containerd/containerd.sock"
crictl config --set \
    runtime-endpoint=unix:///run/containerd/containerd.sock

echo "Kubernetes tools installation completed."