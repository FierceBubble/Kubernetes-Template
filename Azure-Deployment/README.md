# Setting up Kubernetes Cluster using Microsoft Azure VMs With Kata Container running Firecracker MicroVM
## Prerequisite
1. Have at least a free tier of Microsoft Azure Subscription with a max of 4 CPU-cores
2. Built and provision 2 VMs (1 Master node and 1 worker node)
3. Only woker node need to be able to run in a VM with access to bare-metal kernel, master node can run without any access.
4. OS used for both master and worker node can run Ubuntu Linux 18.04 LTS. [Check the list of VM sizes](https://azure.microsoft.com/en-us/pricing/details/virtual-machines/series/#:~:text=The%20VMs%20feature%20up%20to,104%20vCPUs%20on%20isolated%20instances). Size recommended: `Standard_D2s_v3`
5. Dedications and perseverance!

## Preparing VMs for Kubernetes Cluster
### Do below for all machines
```bash
sudo apt update && sudo apt upgrade -y
```
```bash
sudo swapoff -a
```
```bash
cat /proc/meminfo | grep 'SwapTotal'
```
```bash
sudo apt remove docker docker.io containerd runc
```
```bash
sudo modprobe overlay
```
```bash
sudo modprobe br_netfilter
```
```bash
cat <<EOF | sudo tee /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF
```
```bash
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
```
```bash
sudo sysctl --system
```

### DOCKER-CRI Runtime Install (Uncomment to use)
```bash
# sudo apt install apt-transport-https ca-certificates curl software-properties-common gnupg curl lsb-release
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# sudo apt-key fingerprint 0EBFCD88
# sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
# sudo apt update
# sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin
# sudo apt-get update && sudo apt-get install -y \
 # containerd.io=1.2.13-2 \
 # docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs) \
 # docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)
# sudo usermod -aG docker $USER
# sudo bash -c 'cat > /etc/docker/daemon.json <<EOF
 # {
 #  "exec-opts": ["native.cgroupdriver=systemd"],
 #  "log-driver": "json-file",
 #  "log-opts": {
 #    "max-size": "100m"
 #  },
 #   "storage-driver": "overlay2"
 # }
 # EOF'
# sudo mkdir -p /etc/systemd/system/docker.service.d
# sudo systemctl daemon-reload
# sudo systemctl restart docker
# sudo docker info | grep -i cgroup
```

### Containerd Runtime Install
#### Containerd Release list https://github.com/containerd/containerd/releases
##### Below using v1.6.8
```bash
wget https://github.com/containerd/containerd/releases/download/v1.6.8/containerd-1.6.8-linux-amd64.tar.gz
```
```bash
sudo tar Cxzvf /usr/local containerd-1.6.8-linux-amd64.tar.gz
```
```bash
sudo wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service
```
```bash
sudo containerd config default | sudo tee /etc/containerd/config.toml
```
```bash
sudo systemctl daemon-reload
```
```bash
sudo systemctl enable --now containerd
```

#### RunC Release List https://github.com/opencontainers/runc/releases
##### Below using v1.1.7
```shell
wget https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 
```
```bash
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
```
##### ----- Or Skip and use apt package manager -----
```bash
sudo apt install runc
```

#### CNI Plugin Release List https://github.com/containernetworking/plugins/releases
##### Below using v1.3.0
```bash
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz 
```
```bash
sudo mkdir -p /opt/cni/bin
```
```bash
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.3.0.tgz
```

### Install Kubectl, Kubeadm, and Kubelet
```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg  | sudo apt-key add -
```
```bash
sudo bash -c "cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF"
```
```bash
sudo apt-get update
```
```bash
sudo apt-get install -y kubelet kubeadm kubectl
```
```bash
sudo apt-mark hold kubelet kubeadm kubectl
```
```bash
kubeadm version
kubelet --version
kubectl version
```

### Kubernetes Cluster Initialization (Master Node)
###### Run as Root
```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=10.230.0.10
```
Once done, make sure to run
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
Only then you can initialize the connection to the worker node(s)
```bash
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```
We can also use Flannel as our CNI Plugin
```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

## Kata Container - Installing Kata Runtime
There are several ways to install kata cotainer into a machine. In our case we can do it with 2 ways:
1. Automatic using `Kata-deploy` through kubernetes (Not recommended, Need to still configure many things manually)
2. Manually using a binary release file from Kata [Github](https://github.com/kata-containers/kata-containers/releases/) page (Recommended, more controll and less inconsistency)

### Kata-deploy through initiallized Kubernetes Cluster
The full documentation and reference from Kata Container Github page [here](https://github.com/kata-containers/kata-containers/blob/main/tools/packaging/kata-deploy/README.md?plain=1).
##### Apply RBAC to the cluster
```bash
kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-rbac/base/kata-rbac.yaml
```
##### Deploy `Kata-deploy` into the cluster 
```bash
kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-deploy/base/kata-deploy-stable.yaml
```
##### Used to check if `Kata-deploy` has been deployed properlly
```bash
kubectl -n kube-system wait --timeout=10m --for=condition=Ready -l name=kata-deploy pod
```
##### Apply RuntimeClass for pod to reference kata
```bash
kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml
```

### Remove Kata from the Kubernetes cluster
```bash
kubectl delete -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-deploy/base/kata-deploy-stable.yaml
kubectl -n kube-system wait --timeout=10m --for=delete -l name=kata-deploy pod
```

After ensuring kata-deploy has been deleted, cleanup the cluster:
```bash
kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-cleanup/base/kata-cleanup-stable.yaml
```

The cleanup daemon-set will run a single time, cleaning up the node-label, which makes it difficult to check in an automated fashion.
This process should take, at most, 5 minutes.

After that, let's delete the cleanup daemon-set, the added RBAC and runtime classes:
```bash
kubectl delete -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-cleanup/base/kata-cleanup-stable.yaml
kubectl delete -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-rbac/base/kata-rbac.yaml
kubectl delete -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml
```

### Manually install Kata Container into each node
This way of installation of Kata Container is more stable and gives the user more control and less troubleshooting. Though this require more manual and hands-on configuration.

#### Wget Kata Container Binary packages from the official release page
```bash
VERSION=3.1.1 # v3.1.1 is tested!
wget https://github.com/kata-containers/kata-containers/releases/download/${VERSION}/kata-static-${VERSION}-x86_64.tar.xz
```
#### Extract Kata Container Binary packages
```bash
sudo xzcat kata-static-${VERSION}-x86_64.tar.xz | sudo tar -xvf - -C /
```

#### Check if Kata-runtime has been installed properlly
##### Adding Kata runtime dir to be able to call `kata-runtime` in your CLI
```bash
sudo ln -s /opt/kata/bin/kata-runtime /usr/local/bin
sudo ln -s /opt/kata/bin/containerd-shim-kata-v2 /usr/local/bin
```
##### Check Kata-runtime version
```bash
kata-runtime --version
```
##### Adding Kata-runtime into Containerd, configuring `/etc/containerd/config.toml`
```toml
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "kata"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
          runtime_type = "io.containerd.kata.v2"
```
###### If `/etc/containerd/config.toml` does not exist
```bash
sudo containerd config default | sudo tee /etc/containerd/config.toml
```
###### Do These whenever `/etc/containerd/config.toml` changes
```bash
sudo systemctl restart containerd
```

##### Adding RuntimeClassName into kubernetes cluster
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
```

At this point, we can run Kubernetes with Kata Container, by specifying the RuntimeClassName in our deployment manifest.
```yaml
spec:
  template:
    spec:
      runtimeClassName: kata
```


## Firecracker AWS - MicroVM
### Preparing Firecracker
#### Setting up Device Mapper (devmapper)
Firecracker AWS will only work with devmapper instead of aother snapshot like overlayfs or btrfs. We can simply create a sript that will initialized and create a storage pool in `create-devmapper.sh`
```sh
#!/bin/bash
set -ex

DATA_DIR=/var/lib/containerd/devmapper
POOL_NAME=devpool

mkdir -p ${DATA_DIR}

# Create data file
sudo touch "${DATA_DIR}/data"
sudo truncate -s 100G "${DATA_DIR}/data"

# Create metadata file
sudo touch "${DATA_DIR}/meta"
sudo truncate -s 10G "${DATA_DIR}/meta"

# Allocate loop devices
DATA_DEV=$(sudo losetup --find --show "${DATA_DIR}/data")
META_DEV=$(sudo losetup --find --show "${DATA_DIR}/meta")

# Define thin-pool parameters.
# See https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt for details.
SECTOR_SIZE=512
DATA_SIZE="$(sudo blockdev --getsize64 -q ${DATA_DEV})"
LENGTH_IN_SECTORS=$(bc <<< "${DATA_SIZE}/${SECTOR_SIZE}")
DATA_BLOCK_SIZE=128
LOW_WATER_MARK=32768

# Create a thin-pool device
sudo dmsetup create "${POOL_NAME}" \
    --table "0 ${LENGTH_IN_SECTORS} thin-pool ${META_DEV} ${DATA_DEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK}"

cat << EOF
#
# Add this to your config.toml configuration file and restart containerd daemon
#
[plugins]
  [plugins.devmapper]
    pool_name = "${POOL_NAME}"
    root_path = "${DATA_DIR}"
    base_image_size = "10GB"
    discard_blocks = true
EOF
```
We can just execute this once. 
```bash
sudo ./create-devmapper.sh
```
We can check if the storage pool has been initialized successfully
```
sudo dmsetup ls
```
###### Expected output
```bash
$ devpool (253:0)
```

One of the important thing is that devmapper should be initialized and pointed to the directory at each reboot. Or else things might not work properly. We can do that by creating a script in `restart-devmapper.sh` and execute it on reboot through the use of `cron` or `systemd`.
###### Inside the script
```sh
#!/bin/bash
set -ex

DATA_DIR=/var/lib/containerd/devmapper
POOL_NAME=devpool

# Allocate loop devices
DATA_DEV=$(sudo losetup --find --show "${DATA_DIR}/data")
META_DEV=$(sudo losetup --find --show "${DATA_DIR}/meta")

# Define thin-pool parameters.
# See https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt for details.
SECTOR_SIZE=512
DATA_SIZE="$(sudo blockdev --getsize64 -q ${DATA_DEV})"
LENGTH_IN_SECTORS=$(bc <<< "${DATA_SIZE}/${SECTOR_SIZE}")
DATA_BLOCK_SIZE=128
LOW_WATER_MARK=32768

# Create a thin-pool device
sudo dmsetup create "${POOL_NAME}" \
    --table "0 ${LENGTH_IN_SECTORS} thin-pool ${META_DEV} ${DATA_DEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK}"
```

#### Configuring `Containerd`
We should create a script that will tell `containerd` to use `firecracker` configuration instead of the conventional `qemu`. We can create `/usr/local/bin/containerd-shim-kata-fc-v2`
###### In the script
```sh
#!/bin/bash
KATA_CONF_FILE=/opt/kata/share/defaults/kata-containers/configuration-qemu.toml /opt/kata/bin/containerd-shim-kata-v2 $@
```

Make it executable
```bash
sudo chmod +x /usr/local/bin/conatinerd-shim-kata-fc-v2
```

Now we can add both the created script for shim kata runtime and devmapper into our `/etc/containerd/config.toml`
```toml
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-fc]
          runtime_type = "io.containerd.kata-fc.v2"
          snapshotter = "devmapper"
  
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    pool_name = "containerd-pool"
    root_path = "/var/lib/containerd/devmapper"
    base_image_size = "10GB"
```
Lastly we can restart both out `containerd` and `kubelet`
```bash
sudo systemctl restart containerd
```
```bash
sudo systemctl restart kubelet
```


### Final Check of `/etc/containerd/config.toml` should have all of these following things in their respective section.
```toml
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
          runtime_type = "io.containerd.kata.v2"

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-fc]
          runtime_type = "io.containerd.kata-fc.v2"
          snapshotter = "devmapper"
          
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-qemu]
          runtime_type = "io.containerd.kata-qemu.v2"
          
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    pool_name = "containerd-pool"
    root_path = "/var/lib/containerd/devmapper"
    base_image_size = "10GB"
```

## Troubleshooting
Most of the problem will come when the node is rebooted
1. Vhost-vsock: not found
```bash
sudo modprobe vhost_vsock
```
```bash
sudo kata-runtime check
```
```bash
sudo systemctl restart containerd
```
```bash
sudo systemctl restart kubelet
```

2. Most containers are in Unknown state, means we need to reinitialize iptables
```bash
cat <<EOF | sudo tee /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF
```
```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
```
```bash
sudo sysctl --system
```
3. Snapshot /devmapper/ not found, if we alerady setup a script on reboot through cronjob or systemd, we can just
```bash
sudo systemctl restart containerd
```
```bash
sudo systemctl restart kubelet
```
If we have not setup any of those, just re run your script to restart devmapper
```bash
sudo ./restart-devmapper.sh
```
###### In the script
```sh
#!/bin/bash
set -ex

DATA_DIR=/var/lib/containerd/devmapper
POOL_NAME=devpool

# Allocate loop devices
DATA_DEV=$(sudo losetup --find --show "${DATA_DIR}/data")
META_DEV=$(sudo losetup --find --show "${DATA_DIR}/meta")

# Define thin-pool parameters.
# See https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt for details.
SECTOR_SIZE=512
DATA_SIZE="$(sudo blockdev --getsize64 -q ${DATA_DEV})"
LENGTH_IN_SECTORS=$(bc <<< "${DATA_SIZE}/${SECTOR_SIZE}")
DATA_BLOCK_SIZE=128
LOW_WATER_MARK=32768

# Create a thin-pool device
sudo dmsetup create "${POOL_NAME}" \
    --table "0 ${LENGTH_IN_SECTORS} thin-pool ${META_DEV} ${DATA_DEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK}"
```
