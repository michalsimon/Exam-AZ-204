#Login and set a subscription 
az login
az account set --subscription "BizSpark"


#### Windows VM

#list resource groups
az group list --output table 

#Create a resource group if needed.
az group create `
    --name "iaas-demo-rg" `
    --location "westeurope"
    

#Create a Windows VM
az vm create `
    --resource-group "iaas-demo-rg" `
    --name "iaas-demo-win" `
    --image "win2019datacenter" `
    --admin-username "iaasdemoadmin" `
    --admin-password "iaasdemoadmin123$%^" 

#Open RDP 
az vm open-port `
    --resource-group "iaas-demo-rg" `
    --name "iaas-demo-win" `
    --port "3389"

#Get the Public IP 
az vm list-ip-addresses `
    --resource-group "iaas-demo-rg" `
    --name "iaas-demo-win" `
    --output table 

#Clean up 
az group delete --name "iaas-demo-rg"
