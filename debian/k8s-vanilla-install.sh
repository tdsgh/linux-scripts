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

# Detect the CPU architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
esac
echo "CPU Architecture: $ARCH"

# Update and upgrade installed packages
echo "Updating and upgrading installed packages..."
apt update -y && apt upgrade -y

# Install dependencies
echo "Installing dependencies (apt-transport-https ca-certificates curl gpg) ..."
apt install -y apt-transport-https ca-certificates curl gpg


# Check for the presence of systemd-resolved and install it if absent
# if ! systemctl is-active --quiet systemd-resolved; then
#    echo "systemd-resolved is not active. Installing and enabling it..."
#    apt install -y systemd-resolved
#    systemctl enable systemd-resolved
#    systemctl start systemd-resolved
#fi

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

echo "Apply sysctl params without reboot"
sysctl --system

# Get the latest stable release of containerd from GitHub
echo "Fetching and the latest stable release of containerd..."
CONTAINERD_VERSION=$(curl -s https://api.github.com/repos/containerd/containerd/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
if [[ -z "$CONTAINERD_VERSION" ]]; then
    echo "Failed to fetch the latest containerd version."
    exit 1
fi
echo "Containerd version: $CONTAINERD_VERSION"
curl -LO https://github.com/containerd/containerd/releases/download/${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION#v}-linux-${ARCH}.tar.gz
tar -C /usr/local -xzvf containerd-${CONTAINERD_VERSION#v}-linux-${ARCH}.tar.gz
rm containerd-${CONTAINERD_VERSION#v}-linux-${ARCH}.tar.gz

# Configure containerd
echo "Configuring containerd..."
mkdir -p /etc/containerd
CONFIG_FILE="/etc/containerd/config.toml"

#Enable systemd cgroup driver (config.toml has version = 3)
# Use awk to insert the key at the end of the section if it is missing
# SECTION="[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]"
SECTION1=io\.containerd\.cri\.v1\.runtime
SECTION2=containerd\.runtimes\.runc\.options\]
KEY="SystemdCgroup = true"

containerd config default | awk -v section1="$SECTION1" -v section2="$SECTION2" -v key="$KEY" '
    BEGIN { found=0; inserted=0; indent=2 + length(key) }

    $0 ~ section1 && $0 ~ section2 {
        indent += length($0) - length($1);
        found=1;
        print;
        next;
    }
    found && !inserted {
        if($0 ~ /\s*SystemdCgroup/ || !NF || $0 ~ /\s*\[/) {
            printf "%" indent "s\n",  key;
            inserted=1
        }
        if($0 ~ /\s*SystemdCgroup/) next;
    }
    { print }

    END { if (found && !inserted) printf "%" indent "s\n",  key }  # If section was last in file, insert at the end
' > "$CONFIG_FILE"

# RUNC
echo "Install RUNC..."
RUNC_VERSION=$(curl -s https://api.github.com/repos/opencontainers/runc/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
wget https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${ARCH}
install -m 755 runc.arm64 /usr/local/sbin/runc
rm runc.${ARCH}

# Set up systemd service for containerd
echo "Setting up systemd service for containerd..."
curl -LO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mv containerd.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl enable --now containerd

echo "Containerd installation and configuration completed."