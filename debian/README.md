This repo contains scripts to install tools on Debian machine.

## Kubernetes (Vanilla)
Prerequisites:
- Fresh Debian install
- Minimal [Kubernetes requirements](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

Root privileges are required for the installation.
Run the script:
```
su root -c "source k8s-vanilla-install.sh"
```

## NOTES:
- k8s-containerd.sh and k8s-kubetools.sh are executed by k8s-vanilla-install.sh and should not be run manually
- The script was tested on VMs with fresh Debian 12
- Static IP on the VM is preferred
- Complete disabling of swap may not happen, so you should perform a check on reboot and disable manually if necessary (see the output of the installation script). 
