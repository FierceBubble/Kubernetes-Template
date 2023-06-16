# Setting up Kubernetes Cluster using Microsoft Azure VMs With Kata Container running Firecracker MicroVM
## Prerequisite
1. Have at least a free tier of Microsoft Azure Subscription with a max of 4 CPU-cores
2. Built and provision 2 VMs (1 Master node and 1 worker node)
3. Only woker node need to be able to run in a VM with access to bare-metal kernel, master node can run without any access.
4. OS used for both master and worker node can run Ubuntu Linux 18.04 LTS. [Check the list of VM sizes](https://azure.microsoft.com/en-us/pricing/details/virtual-machines/series/#:~:text=The%20VMs%20feature%20up%20to,104%20vCPUs%20on%20isolated%20instances). Size recommended: `Standard_D2s_v3`
5. Dedications and perseverance!

## Preparing VMs for Kubernetes Cluster
### Do below for all machines
```shell
sudo apt update && sudo apt upgrade -y
```
```shell
sudo swapoff -a
```
```shell
cat /proc/meminfo | grep 'SwapTotal'
```
```shell
sudo apt remove docker docker.io containerd runc
```
```shell
sudo modprobe overlay
```
```shell
sudo modprobe br_netfilter
```
```shell
cat <<EOF | sudo tee /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF
```

### DOCKER-CRI Runtime Install (Uncomment to use)
```shell
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
##### Below using v1.7.2
```shell
wget https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz
```
```shell
tar Cxzvf /usr/local containerd-1.7.2-linux-amd64.tar.gz
```
```shell
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service
```
```bash
sudo containerd config default | sudo tee /etc/containerd/config.toml
```
```shell
systemctl daemon-reload
```
```shell
systemctl enable --now containerd
```
##### ----- Or Skip and use apt package manager -----
```bash
sudo apt install containerd
```

#### RunC Release List https://github.com/opencontainers/runc/releases
##### Below using v1.1.7
```shell
wget https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 
```
```shell
install -m 755 runc.amd64 /usr/local/sbin/runc
```
##### ----- Or Skip and use apt package manager -----
```bash
sudo apt install runc
```

#### CNI Plugin Release List https://github.com/containernetworking/plugins/releases
##### Below using v1.3.0
```shell
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz 
```
```shell
mkdir -p /opt/cni/bin
```
```shell
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.3.0.tgz
```

### Install Kubectl, Kubeadm, and Kubelet
```shell
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg  | sudo apt-key add -
```
```shell
sudo bash -c "cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF"
```
```shell
sudo apt-get update
```
```shell
sudo apt-get install -y kubelet kubeadm kubectl
```
```shell
sudo apt-mark hold kubelet kubeadm kubectl
```
```shell
kubeadm version
kubelet --version
kubectl version
```

### Kubernetes Cluster Initialization (Master Node)
###### Run as Root
```shell
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
VERSION=3.1.2 # or any other version you desired
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


## Preparing Worker Node to run Firecracker AWS MicroVM
TBC

#### Final Check of `/etc/containerd/config.toml` should have all of these following things in their respective section.
```toml
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "kata"
      snapshotter = "devmapper"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
          runtime_type = "io.containerd.kata.v2"

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-fc]
          runtime_type = "io.containerd.kata-fc.v3"

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-qemu]
          runtime_type = "io.containerd.kata-qemu.v3"
          
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    pool_name = "containerd-pool"
    root_path = "/var/lib/containerd/io.containerd.snapshotter.v1.devmapper"
    base_image_size = "40GB"
```
