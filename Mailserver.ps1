##first step is login-AzureRM  but this can be commented out if need be
#You'll be making a linux box
#Login-AzureRmAccount



#set the variables for global, need change Image to the SQL Dev 
$location = "westeurope"
$subscription = (Get-AzureRmSubscription -SubscriptionName "Visual Studio Professional").id
$RGname = "WestEurope"


## Storage

##storage variables storage account names must always be lowercase
$StorageType = "Standard_LRS"
$StorAcVM = "mcastorvmgm"
$StorAcDiag  = "mcastorvmgmdiag"
$StorageName = @($StorAcVM,$StorAcDiag)



#network variables
##network 1 and 2 subnets
$Vnet1name = "Westeurope-vnet"
$vnet1range = "172.20.0.0/16"

$Vnet1SN1name = "17220"
$vnet1SN1range = "172.20.1.0/24"


# 1. Create new resource group>
New-AzureRmResourceGroup -Name $RGname -Location $location

############# build the network security group rules
#okay so, make the NSG rule, make the NSG, make the subnets config in memory, then actually create the network with subnets
#rdp rule created to allow RDP in, this is just config - i.e. in Memory

function New-GMNSGRule  ($nsrname, $nsrdirection, $nsrprotocol, $nsrport, $nsrpriority) {
    
    New-Variable -Name ("$nsrnamerule$nsrdirection") -value (New-AzureRmNetworkSecurityRuleConfig -Name "$nsrname-rule" -Description "Allow $nsrname" -Access "Allow" -Protocol $nsrprotocol `
    -Direction Inbound -Priority $nsrpriority -SourceAddressPrefix "Internet" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange $nsrport) -Scope global -Force
}



New-GMNSGRule -nsrname "rdp" -nsrdirection"inbound" -nsrprotocol "tcp" -nsrport 3389 -nsrpriority 100

New-GMNSGRule -nsrname "smtp" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 25 -nsrpriority 110

#this creates the actual NSG which will be used for both networks and all subs
$networkSecurityGroup = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGname -Location $location `
-Name "NSG-FrontEnd" -SecurityRules $rdpRule,$smtprule

#this creates both the subnets for network 1 using the variables declared about
$Subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name $Vnet1SN1name `
-AddressPrefix $vnet1SN1range -NetworkSecurityGroup $networkSecurityGroup -Verbose

# this creates the first network, using the subnets and NSG described above
$Vnet1 = New-AzureRmVirtualNetwork -Name $Vnet1name -ResourceGroupName $RGname `
-Location $location -AddressPrefix $vnet1range -Subnet $subnet1 -Verbose



#####################network end 



# make Storage account 
$StorageName | ForEach-Object {
    New-AzureRmStorageAccount -ResourceGroupName $RGname -Name $_ -Type $StorageType -Location $location -verbose

}

# Compute

#make the network cards for the VMs

# make  public IP, attach them to network card
$Nicname1 = "ckmailboxNIC"
$Subnet1 = $Vnet1.Subnets[0].Id
$PIp1 = New-AzureRmPublicIpAddress -verbose -Name $Nicname1 -ResourceGroupName $Rgname -Location $Location -AllocationMethod static
$Nic1 = New-AzureRmNetworkInterface -verbose -Name $Nicname1 -ResourceGroupName $Rgname -Location $Location -SubnetId $Subnet1 -PublicIpAddressId $PIp1.Id


#make Availability set

$availSet1 = New-AzureRmAvailabilitySet -verbose -ResourceGroupName $RGname -Location $location -Name $availSetname

## Setup local VM object in memory, you'll need a long password




$publisher = "Canonical"
$Offer = "UbuntuServer"
$sku = "14.04.05-LTS" 
$VMSize ="Standard_B2s"
$VMname1 = "CKmailbox"   #this will also become the actual Computer object. so within the VM image. i.e. the OS or domain computer name
$availSetname = "CKMailAV"
$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $RGname -Name $StorAcVM
$OSDiskName1 = $VMName1 + "OSDisk"


##get login creds for the actual computers
$Credential = Get-Credential

##create vm1
# basic config, size and name
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName1 -VMSize $VMSize -AvailabilitySetId $availSet1.id
#setting the core image (server 2016 prob. set above in variable)
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $publisher -Offer $offer -Skus $sku -Version "latest"
#setting the OS variables to appy with the deployment, watch for computer name
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $vmname1 -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
#adding the previously made network card
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Nic1.Id
#add the OS disk location, dont think you actually need the ToString NOW WE MIGHT WANT MANAGED DISK INSTEAD
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName1 + ".vhd"
#lastly the vm OS disk options 
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName1 -VhdUri $OSDiskUri -CreateOption FromImage
 
 #create the previously 'built' vm object in Azure
New-AzureRmVM -ResourceGroupName $Rgname -VM $VirtualMachine -Location $location -verbose

