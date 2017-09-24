## this script assumes you're calling your item box.mydomain.com it also assumes you're using mailinabox.
#you will need to login-azumermaccount

#everything defaults to "Mymailbox" you can find replace if like. I've left naming flexible.
# MAKE SURE YOU'RE ON THE CORRECT SUBSCRIPTION if you have more than one 

$location = "westeurope"
$RGname = "WestEurope" #rolegroup name

## Storage
##storage variables storage account names must always be lowercase
$StorageType = "Standard_LRS"   
$StorAcname = "mymailboxsa"

#network variables
##network subnet
$Vnet1name = "Westeurope-vnet"
$vnet1range = "172.20.0.0/16"

$Vnet1SN1name = "172201"
$vnet1SN1range = "172.20.1.0/24"

$VMSize ="Standard_B1m"   #you can probably change this to a B1s after it's made tbh in the poral
$VMname1 = "mymailbox"   #this will also become the actual Computer object. so within the VM image. i.e. the OS or domain computer name
$availSetname = "mymailboxAvSet"
$Nicname1 = "mymailboxNIC"
$reverseFQDN = "box.mydomainname.com"


# 1. Create new resource group>
New-AzureRmResourceGroup -Name $RGname -Location $location

############# build the network security group rules
#you make multiple security rules, then when you make the network security group, it's created with all those rules embedded.
# mailinabox script itself will take care of firewall settings on the machine.

#little function just to make creating the rules easier to read. 
function New-GMNSGInRule  ($nsrname, $nsrdirection, $nsrprotocol, $nsrport, $nsrpriority) {
   
   $name =  $nsrname + "rule" +   $nsrdirection.substring(0,2) 
    New-Variable -Name $name -value (New-AzureRmNetworkSecurityRuleConfig -Name "$nsrname-rule" -Description "Allow $nsrname" -Access "Allow" -Protocol $nsrprotocol `
    -Direction $nsrdirection -Priority $nsrpriority -SourceAddressPrefix "Internet" -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange $nsrport) -Scope global -Force
}

#: 22 (SSH), 25 (SMTP), 53 (DNS; must be open for both tcp & udp), 80 (HTTP), 443 (HTTPS), 587 (SMTP submission), 993 (IMAP), 995 (POP) and 4190 (Sieve).

New-GMNSGInRule -nsrname "ssh" -nsrdirection "inbound" -nsrprotocol "tcp" -nsrport 22 -nsrpriority 100
New-GMNSGInRule -nsrname "smtp" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 25 -nsrpriority 110
New-GMNSGInRule -nsrname "dns" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 53 -nsrpriority 120
New-GMNSGInRule -nsrname "http" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 80 -nsrpriority 130
New-GMNSGInRule -nsrname "https" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 443 -nsrpriority 140
New-GMNSGInRule -nsrname "SMTPsubmis" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 587 -nsrpriority 150
New-GMNSGInRule -nsrname "IMAP" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 993  -nsrpriority 160
New-GMNSGInRule -nsrname "POP" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 995  -nsrpriority 170
New-GMNSGInRule -nsrname "Sieve" -nsrdirection "inbound" -nsrprotocol "*" -nsrport 4190  -nsrpriority 180

#this creates the actual NSG which will be used for both networks and all subs
$nsgname = "mailnsg"
$networkSecurityGroup = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGname -Location $location -Name $nsgname `
-SecurityRules  $dnsrulein, $httprulein, $httpsrulein, $IMAPrulein, $POPrulein, $Sieverulein, $smtprulein, $SMTPsubmisrulein, $sshrulein


#this creates both the subnets for network 1 using the variables declared about
$Subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name $Vnet1SN1name `
-AddressPrefix $vnet1SN1range -NetworkSecurityGroup $networkSecurityGroup -Verbose

# this creates the first network, using the subnets and NSG described above
$Vnet1 = New-AzureRmVirtualNetwork -Name $Vnet1name -ResourceGroupName $RGname `
-Location $location -AddressPrefix $vnet1range -Subnet $subnet1 -Verbose

### creating the public IP  and NIc , setting the Reverse FQDN

$Subnet1 = $Vnet1.Subnets[0].Id
$Pip1 = New-AzureRmPublicIpAddress -verbose -Name $Nicname1 -ResourceGroupName $Rgname -Location $Location -AllocationMethod static
$Pip1.DnsSettings.ReverseFqdn = $reverseFQDN
Set-AzureRmPublicIpAddress -PublicIpAddress $Pip1
#create NICE
$Nic1 = New-AzureRmNetworkInterface -verbose -Name $Nicname1 -ResourceGroupName $Rgname -Location $Location -SubnetId $Subnet1 -PublicIpAddressId $Pip1.Id


#####################network end 


# make Storage account 
New-AzureRmStorageAccount -ResourceGroupName $RGname -Name $StorAcname -Type $StorageType -Location $location -verbose

####################### Compute start

#make Availability set

$availSet1 = New-AzureRmAvailabilitySet -verbose -ResourceGroupName $RGname -Location $location -Name $availSetname

## Setup local VM object in memory, you'll need a long password

$publisher = "Canonical"
$Offer = "UbuntuServer"
$sku = "14.04.5-LTS" 

$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $RGname -Name $StorAcname
$OSDiskName1 = $VMName1 + "OSDisk"


##get login creds for the actual computers
$Credential = Get-Credential

##create vm1
# basic config, size and name
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName1 -VMSize $VMSize -AvailabilitySetId $availSet1.id
#setting the core image (server 2016 prob. set above in variable)
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $publisher -Offer $offer -Skus $sku -Version "latest"
#setting the OS variables to appy with the deployment, watch for computer name
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $vmname1 -Credential $Credential 
#adding the previously made network card
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Nic1.Id
#add the OS disk location, dont think you actually need the ToString NOW WE MIGHT WANT MANAGED DISK INSTEAD
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName1 + ".vhd"
#lastly the vm OS disk options 
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName1 -VhdUri $OSDiskUri -CreateOption FromImage
 
 #create the previously 'built' vm object in Azure
New-AzureRmVM -ResourceGroupName $Rgname -VM $VirtualMachine -Location $location -verbose

