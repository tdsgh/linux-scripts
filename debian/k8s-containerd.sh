#!/bin/bash
# This script installs a Kubernetes tools.
# Author: Dmitry
# Date: 2025-04-05
# Last changes: 2025-04-05
# Usage: ./k8s-containerd.sh

echo
echo "Installing containerd runtime for Kubernetes..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
esac
echo "CPU Architecture: $ARCH"

# Get the latest stable release of containerd from GitHub
echo "Fetching the latest stable release of containerd..."
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
echo
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
echo
echo "Install RUNC..."
RUNC_VERSION=$(curl -s https://api.github.com/repos/opencontainers/runc/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
wget https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${ARCH}
install -m 755 runc.arm64 /usr/local/sbin/runc
rm runc.${ARCH}

# Set up systemd service for containerd
echo
echo "Setting up systemd service for containerd..."
curl -LO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mv containerd.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl enable --now containerd

echo "Containerd installation and configuration completed."