#Login and set a subscription
Connect-AzAccount -SubscriptionName 'BizSpark'
Set-AzContext -SubscriptionName 'BizSpark'

#Create a Resource Group
New-AzResourceGroup -Name "iaas-demo-rg" -Location "WestEurope"

#Create a VM credentials
$username = 'iaasdemoadmin'
$password = ConvertTo-SecureString 'iaasdemoadmin123$%^' -AsPlainText -Force
$WindowsCred = New-Object System.Management.Automation.PSCredential ($username, $password)

#Create a Windows VM
New-AzVM `
    -ResourceGroupName 'iaas-demo-rg' `
    -Name 'iaas-demo-win' `
    -Image 'Win2019Datacenter' `
    -Credential $WindowsCred `
    -OpenPorts 3389

#Get the Public IP 
Get-AzPublicIpAddress `
    -ResourceGroupName 'iaas-demo-rg' `
    -Name 'iaas-demo-win' | Select-Object IpAddress

#Clean up 
Remove-AzResourceGroup -Name 'iaas-demo-rg'