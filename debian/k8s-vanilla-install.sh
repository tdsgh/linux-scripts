#!/bin/bash
# This script installs a vanilla Kubernetes cluster on Linux.
# Author: Dmitry
# Date: 2025-03-30
# Last changes: 2025-03-30
# Usage: ./k8s-vanilla-install.sh

set -euo pipefail

# Detect the current operating system
if [[ "$OSTYPE" == "linux-gnu"* && -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "debian" ]]; then
        echo "This script is intended for Debian-based distributions."
        exit 1
    fi
    echo "Distribution: $ID"
else
    echo "This script is intended for Linux systems with /etc/os-release available."
    exit 1
fi

# Update and upgrade installed packages
echo "Updating and upgrading installed packages..."
apt update -y && apt upgrade -y

# Install dependencies
echo
echo "Installing dependencies (apt-transport-https ca-certificates curl gpg) ..."
apt install -y apt-transport-https ca-certificates curl gpg

echo
echo "Setting up prerequisites for containerd runtime"
modprobe overlay
modprobe br_netfilter
cat <<EOF | tee /etc/modules-load.d/k8s-containerd.conf
overlay
br_netfilter
EOF

echo "Enable required sysctl params, these persist across reboots"
cat <<EOF | tee /etc/sysctl.d/k8s-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

echo
echo "Apply sysctl params without reboot"
sysctl --system

source k8s-containerd.sh
source k8s-kubetools.sh

echo
echo "Kubernetes installation completed."