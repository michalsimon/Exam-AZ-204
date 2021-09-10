#Login and set a subscription 
az login
az account set --subscription "BizSpark"


#### Linux VM

#list resource groups
az group list --output table 

#Create a resource group if needed.
az group create `
    --name "iaas-demo-rg" `
    --location "westeurope"
    

#Create a Linux VM
az vm create `
    --resource-group "iaas-demo-rg" `
    --name "iaas-demo-linux" `
    --image "UbuntuLTS" `
    --admin-username "iaasdemoadmin" `
    --authentication-type "ssh" `
    --ssh-key-value ~/.ssh/id_rsa.pub 

#Open SSH 
az vm open-port `
    --resource-group "iaas-demo-rg" `
    --name "iaas-demo-linux" `
    --port "22"

#Get the Public IP 
az vm list-ip-addresses `
    --resource-group "iaas-demo-rg" `
    --name "iaas-demo-linux" `
    --output table

#Log into the Linux VM over SSH
ssh demoadmin@<PUBLIC_IP>

#Clean up the resources 
az group delete --name "iaas-demo-rg"
