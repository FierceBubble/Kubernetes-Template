# Setting up Kubernetes Clusters using Microsoft Azure VMs
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
```shell
systemctl daemon-reload
```
```shell
systemctl enable --now containerd
```

#### RunC Release List https://github.com/opencontainers/runc/releases
##### Below using v1.1.7
```shell
wget https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64 
```
```shell
install -m 755 runc.amd64 /usr/local/sbin/runc
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

### Kubernetes Cluster Initialization
```shell
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=10.230.0.10
```

### Troubleshooting
```shell
echo 1 > /proc/sys/net/ipv4/ip_forward
```
```shell
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```
