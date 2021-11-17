#Login and set a subscription 
az login
az account set --subscription "BizSpark"

#List resource groups
az group list --output table 

#Create a resource group if needed.
az group create `
    --name "iaas-demo-rg" `
    --location "westeurope"



#Deploy a container from Azure Container Registry with authentication

# ACR_REGISTRY_NAME: The name of your Azure Container Registry
$ACR_REGISTRY_NAME='iaasdemoacr'
# SERVICE_PRINCIPAL_NAME: Must be unique within your AD tenant
$SERVICE_PRINCIPAL_NAME='acr-service-user'


#Obtain the registry ID and login server
$ACR_REGISTRY_ID=$(az acr show --name $ACR_REGISTRY_NAME --query id --output tsv)
$ACR_LOGINSERVER=$(az acr show --name $ACR_REGISTRY_NAME --query loginServer --output tsv)

echo "ACR ID: $ACR_REGISTRY_ID"
echo "ACR Login Server: $ACR_LOGINSERVER"


# Create the service principal with rights scoped to the registry.
# Default permissions are for docker pull access. Modify the '--role'
# argument value as desired:
# acrpull:     pull only
# acrpush:     push and pull
# owner:       push, pull, and assign roles
$SERVICE_PRINCIPAL_PASSWORD=$(az ad sp create-for-rbac `
--name $SERVICE_PRINCIPAL_NAME `
--scopes $ACR_REGISTRY_ID `
--role acrpull `
--query password `
--output tsv)

$SERVICE_PRINCIPAL_APPID=$(az ad sp list `
--display-name $SERVICE_PRINCIPAL_NAME `
--query "[].appId" `
--output tsv)

# Output the service principal's credentials; use these in your services and
# applications to authenticate to the container registry.
echo "Service principal ID: $SERVICE_PRINCIPAL_APPID"
echo "Service principal password: $SERVICE_PRINCIPAL_PASSWORD"


#Create the container in ACI
az container create `
--resource-group iaas-demo-rg `
--name iaas-demo-dockerwebapp `
--dns-name-label iaas-demo-dockerwebapp `
--ports 80 `
--image $ACR_LOGINSERVER/dockerwebapp:v1 `
--registry-login-server $ACR_LOGINSERVER `
--registry-username $SERVICE_PRINCIPAL_APPID `
--registry-password $SERVICE_PRINCIPAL_PASSWORD


#Confirm the container is running and test access to the web application
az container show --resource-group iaas-demo-rg --name iaas-demo-dockerwebapp  


#Get the URL of the container running in ACI
URL=$(az container show --resource-group iaas-demo-rg --name iaas-demo-dockerwebapp --query ipAddress.fqdn | tr -d '"') 
echo $URL
curl $URL


#Pull the logs from the container
az container logs --resource-group  iaas-demo-rg --name iaas-demo-dockerwebapp


#Delete the running container
az container delete  `
    --resource-group  iaas-demo-rg `
    --name iaas-demo-dockerwebapp `
    --yes


#Clean up (this will delete all of the ACIs and the ACR deployed in this resource group)
az group delete --name  iaas-demo-rg --yes