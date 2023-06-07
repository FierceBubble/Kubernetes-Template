loc=eastasia
rg='rg-kata'
# storageacc=katastorage
vmimage=ubuntults
shutdownutc=1230 #Auto Shutdown time in UTC

vnet='kata-vnet';subnet='kata-subnet';
nsg='kata-nsg';

vnetaddressprefix='10.230.0.0/24'
subnetaddressprefix='10.230.0.0/27'

# Controller VM should have > 2 cpu
controllervmsize='Standard_B2s' # check the available vm sizes in your region
size='Standard_DS1'
# az vm list-sizes -l eastus -o table

controllervmprivateip='10.230.0.10'
controllerpip='controller-pip'
controllernic='controller-nic'

clientvmprivateip='10.230.0.15'
clientpip='client-pip'
clientnic='client-nic'

workervmsize='Standard_D2s_v3' # This is bare-metal. Compatible with Kata Container
workerprivateippref='10.230.0.2'
workeravblset='worker-avblset'


adminuser=bubble
echo 'admin username is $adminuser'

adminpwd='Mgeng@r070700'
# ask for password
# read -s -p "Enter admin Password (should be minimum 12 char strong): " adminpwd
# echo $adminpwd #must be min 12 char long with one number, one special char and alphabet

clientvm='kata-client'
controllervm='controller-vm'

# to stop 
# az vm deallocate --ids $(az vm list -d -g $rg --query "[?powerState=='VM running'].id" -o tsv)
# az vm deallocate --ids $(az vm list -d -g $rg --query "[].id" -o tsv)
echo "----------------- 1 Creating Resource Group -----------------"
# Create Resource Group in 
az group create -n $rg -l $loc

echo "----------------- 2 Creating Storage Account -----------------"
# Create storage account and storage container
# No need to create any container or use the storage account name while creating vm 
# Because VM will find a storage account in the same resource group and create a container if not present vhds 
# if no storage account is available then vm create will create a storage account if --use-umamanged-disk option is provided.
# az storage account create -n $storageacc -g $rg --sku Standard_LRS
#az storage container create -n vmhdd --account-name $storageacc
echo "Storage Account will be created Automatically while the first VM is created. This is to avoid the name conflict."

echo "----------------- 3 Creating Virtual Network -----------------"
# Create virtual network
az network vnet create -g $rg -n $vnet --address-prefix $vnetaddressprefix

echo "----------------- 4 Creating NSG -----------------"
# Create NSG
az network nsg create -g $rg -n $nsg

# Create a firewall rule to allow external SSH and HTTPS
az network nsg rule create -g $rg -n k8s-allow-ssh --access allow --destination-address-prefixes '*' --destination-port-range 22 --direction inbound --nsg-name $nsg --protocol tcp --source-address-prefixes '*' --source-port-range '*' --priority 1000

az network nsg rule create -g $rg -n k8s-allow-api-server --access allow --destination-address-prefixes '*' --destination-port-range 6443 --direction inbound --nsg-name $nsg --protocol tcp --source-address-prefixes '*' --source-port-range '*' --priority 1001

az network nsg rule create -g $rg -n k8s-allow-kubectl-commands --access allow --destination-address-prefixes '*' --destination-port-range 8080 --direction inbound --nsg-name $nsg --protocol tcp --source-address-prefixes '*' --source-port-range '*' --priority 1002

az network nsg rule create -g $rg -n k8s-allow-kubelet-check --access allow --destination-address-prefixes '*' --destination-port-range 10248 --direction inbound --nsg-name $nsg --protocol tcp --source-address-prefixes '*' --source-port-range '*' --priority 1003

echo "----------------- 5 Creating Subnet -----------------"
# Create Subnet
az network vnet subnet create -g $rg --vnet-name $vnet -n $subnet --address-prefixes $subnetaddressprefix --network-security-group $nsg

echo "----------------- 6 Creating Client VM's Public IP -----------------"
# Create nic and pip for controller VM
# az network public-ip create -n $clientpip -g $rg
echo "Using your own machine as a client"

echo "----------------- 7 Creating Client VM's NIC -----------------"
# az network nic create -g $rg -n $clientnic --private-ip-address $clientvmprivateip --public-ip-address $clientpip --vnet $vnet --subnet $subnet --ip-forwarding
# Client VM which will be acting as gateway
echo "Using your own machine as a client"

echo "----------------- 8 Creating Client VM-----------------"
# az vm create -g $rg -n $clientvm --image $vmimage --nics $clientnic --size $size --authentication-type password --admin-username $adminuser --admin-password $adminpwd --use-unmanaged-disk --storage-sku Standard_LRS --os-disk-size-gb 200
# az vm auto-shutdown -g $rg -n $clientvm --time $shutdownutc
echo "Using your own machine as a client"

echo "----------------- 9 Creating Controller VM' NIC & Public IP -----------------"
# Controller Public IP
az network public-ip create -n $controllerpip -g $rg

# Controller NIC
az network nic create -g $rg -n $controllernic --private-ip-address $controllervmprivateip --public-ip-address $controllerpip --vnet $vnet --subnet $subnet --ip-forwarding

echo "----------------- 10 Creating Controller VM and Provisioning AutoShutdown -----------------"
# Provision controller VM use  --no-wait
az vm create -g $rg -n $controllervm --image $vmimage --nics $controllernic --size $controllervmsize --authentication-type password --admin-username $adminuser --admin-password $adminpwd --use-unmanaged-disk --storage-sku Standard_LRS --os-disk-size-gb 200
az vm auto-shutdown -g $rg -n $controllervm --time $shutdownutc

# WORKER
echo "----------------- 11 Creating Worker VM's NIC, VM and Provisioning AutoShutdown -----------------"
# Create availability set, nics and pips for worker VMs
az vm availability-set create -g $rg -n $workeravblset --unmanaged

# Provision worker VMs
# Use Loop for >1 nic and VMs - no Public IP
for i in 0; do 
	echo "----------------- 11a. Creating Worker VM's Public IP($i) -----------------"
	# az network public-ip create -n worker-${i}-publicip -g $rg 
        echo "Using Private IP to connect and configure through Controller"

	echo "----------------- 11b. Creating Worker VM's NIC($i) -----------------"
	# az network nic create -g $rg -n worker-${i}-nic --private-ip-address $workerprivateippref${i} \
	#		--public-ip-address worker-${i}-publicip --vnet $vnet --subnet $subnet --ip-forwarding

	az network nic create -g $rg -n worker-${i}-nic --private-ip-address $workerprivateippref${i} \
			--vnet $vnet --subnet $subnet --ip-forwarding

	echo "----------------- 11c. Creating Worker VM($i) -----------------"
	az vm create -g $rg -n worker-${i} --image $vmimage --availability-set  $workeravblset \
		--nics worker-${i}-nic --size $workervmsize --authentication-type password --admin-username $adminuser \
		--admin-password $adminpwd --use-unmanaged-disk --storage-sku Standard_LRS --os-disk-size-gb 200 
	
	echo "----------------- Configuring Worker VM's Auto Shutdown($i) -----------------"
 	az vm auto-shutdown -n worker-${i} -g $rg --time $shutdownutc #UTC Zone
done

echo "----------------- DONE -----------------"
