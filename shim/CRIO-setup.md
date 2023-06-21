# Setting up CRI-O shim for kubernetes cluster
## Installing CRI-O in nodes as a shim  (All command should be run as root)
### Pre-requisite
```bash
modprobe overlay
```
```bash
modprobe br_netfilter
```
```bash
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
```
```bash
sysctl --system
```
```bash
swapoff -a
```

### Installing CRI-O
```bash
lsb_release -a
```
```bash
OS=xUbuntu_18.04
```
```bash
VERSION=1.20
```
```bash
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
```
```bash
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
```
```bash
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | apt-key add -
```
```bash
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | apt-key add -
```
```bash
apt-get update
```
```bash
apt-get install cri-o cri-o-runc cri-tools
```
Edit `/etc/crio/crio.conf`
```conf
conmon= "/usr/bin/conmon"
```
Check if CRI-O installed correctly
```bash
crictl info
```
