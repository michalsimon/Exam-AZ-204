#Login and set a subscription 
az login
az account set --subscription "BizSpark"

#List resource groups
az group list --output table 

#Create a resource group if needed.
az group create `
    --name "iaas-demo-rg" `
    --location "westeurope"


#Create an Azure Container Registry
$ACR_REGISTRY_NAME='iaasdemoacr'  
az acr create  `
    --resource-group iaas-demo-rg `
    --name $ACR_REGISTRY_NAME `
    --sku Standard 


#Login to ACR
az acr login --name $ACR_REGISTRY_NAME
 

#Get the loginServer which is used in the image tag
$ACR_LOGINSERVER=$(az acr show --name $ACR_REGISTRY_NAME --query loginServer --output tsv)
echo $ACR_LOGINSERVER


#Tag the image using the login server name
#[loginUrl]/[repository:][tag]
docker tag dockerwebapp:v1 $ACR_LOGINSERVER/dockerwebapp:v1
docker image ls $ACR_LOGINSERVER/dockerwebapp:v1


#Push image to Azure Container Registry
docker push $ACR_LOGINSERVER/dockerwebapp:v1


####  ACR Tasks
#Use ACR build to build our image in azure and then push that into ACR
az acr build --image "dockerwebapp:v1-acr-task" --registry $ACR_REGISTRY_NAME .


#Get a listing of the repositories and images/tags in our Azure Container Registry
az acr repository list --name $ACR_REGISTRY_NAME --output table
az acr repository show-tags --name $ACR_REGISTRY_NAME --repository dockerwebapp --output table