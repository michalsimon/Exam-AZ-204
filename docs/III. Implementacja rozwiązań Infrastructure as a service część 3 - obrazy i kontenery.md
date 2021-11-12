# III. Implementacja rozwiązań Infrastructure as a service część 3 - obrazy i kontenery

**Implementacja rozwiązań IaaS** jest częścią tematu **Develop Azure compute solutions** egzaminu **AZ-204**.

Umiejętności badane w tej części egzaminu:
* Uruchamianie maszyn wirtualnych (**VM**)
* Konfiguracja, walidacja i wdrażanie **szablonów ARM**
* **Konfiguracja obrazów kontenerów** 
* **Publikacja obrazów w **Azure Container Registry****
* **Uruchamianie kontenerów za pomocą **Azure Container Instance****

## 1. Konfiguracja obrazów kontenerów

![](pic/azure%20and%20docker.jpg)

### Podstawy konteneryzacji
Konteneryzacja aplikacji pozwala na spakowanie plików binarnych, bibliotek i innych wymaganych komponentów programu w jeden możliwy do wdrożenia pakiet binarny zwany obrazem kontenera. Uruchomione wystąpienie obrazu kontenera jest nazywane kontenerem, a wewnątrz tego kontenera znajduje się uruchomiona aplikacja. Dzięki temu Twoja aplikacja działa i może wykorzystywać zasoby zapewniane przez system operacyjny. 

Ogólnie rzecz biorąc, uruchamiamy jedną aplikację wewnątrz kontenera a obraz kontenera jest mechanizmem wdrażania aplikacji. Dlatego obrazy kontenerów są na ogół bardzo małe i przenośne. 

Kluczowym sposobem aby obrazy kontenerów stały się przenośne, są rejestry kontenerów, które umożliwiają łatwe udostępnianie i używanie obrazów kontenerów.

### Obrazy Docker
W swojej najbardziej podstawowej formie plik **Dockerfile** to sekwencja poleceń lub instrukcji używanych do tworzenia obrazu kontenera i tworzenia środowiska wewnątrz kontenera dla aplikacji. 

Typowe instrukcje w pliku **Dockerfile** obejmują:
* Kopiowanie skompilowanego pliku binarnego aplikacji do obrazu kontenera
* Definiowanie które pliki binarne lub skrypty są uruchamiane gdy kontener jest uruchamiany z obrazu 
* Kopiowanie plików konfiguracyjnych 
* Ustawianie zmiennych środowiskowych

Po zapisaniu pliku **Dockerfile** wykonując polecenie `docker build` tworzy się obraz kontenera binarnego przechowywany na lokalnej stacji roboczej. 
Wewnątrz tego obrazu znajdują się pliki binarne aplikacji i konfiguracja potrzebne do uruchomienia aplikacji w kontenerze. 
Po utworzeniu obrazu kontenera można go uruchomić lokalnie jako kontener w celu przetestowania aplikacji. Działający obraz kontenera, można wypchnąć do rejestru kontenerów gdzie będzie dostępny do pobrania dla innych użytkowników.

### Przykładowy plik Dockerfile tworzony przez Visual Studio
Plik **Dockerfile** używany przez program *Visual Studio* jest podzielony na wiele etapów. Ten proces opiera się na funkcji wieloetapowej kompilacji platformy Docker.

Funkcja kompilacji wieloetapowej pomaga zwiększyć wydajność procesu kompilowania kontenerów i zmniejsza kontenery, pozwalając im zawierać tylko te fragmenty, których aplikacja potrzebuje w czasie wykonywania.

Jako przykład rozważmy typowy plik **Dockerfile** wygenerowany przez *Visual Studio*:

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /src
COPY ["dockerwebapp.csproj", "."]
RUN dotnet restore "./dockerwebapp.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "dockerwebapp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "dockerwebapp.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "dockerwebapp.dll"]
```

#### Pierwszym etapem budowania obrazu jest **base**: 
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS base
WORKDIR /app
EXPOSE 80
```

Zaczyna się on od instrukcji **FROM** od której zaczyna się większość plików **Dockerfile**. Definiuje to podstawowy obraz kontenera używany w kolejnych instrukcjach w pliku **Dockerfile**. 

W przykładzie używamy obrazu *aspnet:5.0* z rejestru kontenerów *mcr.microsoft.com*. Jest to oficjalny obraz kontenera firmy Microsoft, zapewniający podstawowe funkcje potrzebne do uruchomienia aplikacji *.NET Core* w kontenerze. 

Etap ten definiuje bazowy obraz pośredni `base`, który udostępnia port `80` za pomocą instrukcji `EXPOSE` i ustawia katalog roboczy na `/app` za pomocą instrukcji `WORKDIR`.


#### Kolejnym etapem jest **build**, który wygląda następująco:
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /src
COPY ["dockerwebapp.csproj", "."]
RUN dotnet restore "./dockerwebapp.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "dockerwebapp.csproj" -c Release -o /app/build
```

Jak widać etap ten zaczyna się od użycia obrazu *sdk:5.0* z rejestru (obraz sdk zawiera wszystkie narzędzia do kompilacji iz tego powodu jest znacznie większy niż obraz aspnet).

Instrukcja `WORKDIR` ustawia katalog roboczy na `/src/.`.

Instrukcja `COPY` kopiuje plik aplikacji z lokalnego katalogu stacji roboczej do obrazu kontenera.

Instrukcja `RUN` wykonuje polecenia wewnątrz kontenera. 
W tym przypadku uruchamia polecenie `dotnet restore`, które odtwarza zależności dla projektu zapisane w pliku `.csproj` oraz `dotnet build`, które buduje projekt i jego zależności.

#### Kolejnym etapem jest **publish**, który wygląda następująco:
```dockerfile
FROM build AS publish
RUN dotnet publish "dockerwebapp.csproj" -c Release -o /app/publish
```
W tym etapie pliki binarne aplikacji są publikowane do ścieżki `/app/publish` z pomocą narzędzia `dotnet build` zainstalowanego w obrazie pośrednim `build`, który jest obrazem bazowym tego etapu.

#### Ostatnim etapem jest **final**, który wygląda następująco:
```dockerfile
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "dockerwebapp.dll"]
```

Zaczyna się on od obrazu pośredniego `base` i zwiera instrukcję `COPY --from=publish /app/publish .`, która kopiuje opublikowane pliki binarne do obrazu `final`. 

Ostatnią instrukcją jest instrukcja `ENTRYPOINT`, która służy do zdefiniowania, który skrypt lub plik binarny chcemy uruchomić w czasie kiedy kontener jest uruchamiany z tego obrazu kontenera. W nawiasach kwadratowych definiujemy polecenie, które chcemy uruchomić a następnie jego parametry. Tak więc uruchomimy polecenie `dotnet` z parametrem naszego skompilowanego pliku binarnego aplikacji, czyli `dockerwebapp.dll`.

#### Komenda budująca obraz
```powershell
docker build -t dockerwebapp:v1 .
```
Obraz kontenera budujemy wykonując polecenie `docker build`. 

Pojedyncza kropka powoduje budowanie obrazu kontenera z pliku **Dockerfile** znajdującego się w bieżącym katalogu.

Parametr `-t` służy do nadawania nazwy `dockerwebapp` obrazowi kontenera i oznaczania go tagiem `v1`.

#### Demo
Plik ze skryptem uruchomienia testowej aplikacji dostępny jest tutaj:
[run-app-in-docker.ps1](https://github.com/michalsimon/Exam-AZ-204/blob/main/src/IaaS/run-app-in-docker.ps1)

```powershell
cd ./dockerwebapp

#Step 1 - build the container defined in the Dockerfile
docker build -t dockerwebapp:v1 .

#Step 2 - check if image exist
docker image ls dockerwebapp:v1

#Step 3 - run the container locally 
docker run --name dockerwebapp --publish 8080:80 --detach dockerwebapp:v1
curl http://localhost:8080

#Step 4 - delete the running container
docker stop dockerwebapp
docker rm dockerwebapp
```

## 2. Publikacja obrazów w Azure Container Registry


## 3. Uruchamianie kontenerów za pomocą Azure Container Instance







#### Demo
```powershell
#####################################################################################
# Requirements for this demo
# 1. Install docker          - https://docs.docker.com/desktop/#download-and-install 
# 2. Install dotnet core sdk - https://dotnet.microsoft.com/download/dotnet-core
#####################################################################################
cd ./m2/demos


#This is our simple hello world web app and will be included in the course downloads.
ls -ls ./webapp


#Step 1 - Build our web app first and test it prior to putting it in a container
dotnet build ./webapp
dotnet run --project ./webapp #Open a new terminal to test.
curl http://localhost:5000


#Step 2 - Let's publish a local build...this is what will be copied into the container
dotnet publish -c Release ./webapp


#Step 3 - Time to build the container and tag it...the build is defined in the Dockerfile
docker build -t webappimage:v1 .


#In docker 3.0, by default output from commands run in the container during the build aren't written to console
#Add you need to add --progress plain to see the output from commands running during the build
#If you already built the image you'll need to delete the image and your build cache so new layers are built
#docker rmi webappimage:v1 && docker builder prune --force && docker image prune --force
#docker build --progress plain -t webappimage:v1 .


#Step 4 - Run the container locally and test it out
docker run --name webapp --publish 8080:80 --detach webappimage:v1
curl http://localhost:8080


#Delete the running webapp container
docker stop webapp
docker rm webapp


#The image is still here...let's hold onto this for the next demo.
docker image ls webappimage:v1
```


## IV. Publish an image to the Azure Container Registry

### Azure Container Registry (ACR)
Azure Container Registry is a managed Docker Registry service based on the open source Docker Registry, allowing you to build, store, and manage container images for container deployments. ACR can be a core component of a CI/CD pipeline. It can be integrated into your source control systems and build container images when code is committed. Further, container orchestrators, such as Kubernetes, and serverless platforms, like Azure Container Instances, can be configured to pull images from Azure Container Registry. Further, you can use Azure Container Registry tasks to streamline building, testing, pushing, and deploying images in Azure. ACR Tasks offloads the build process of your application into Azure Container Registry and can be triggered to build a container image when your team commits code into source control. And then that image will automatically be pushed into your container registry when the task is complete. 
There are several ACR service tiers. Basic, Standard, and Premium are the current service tiers. As you move up in service tier, you will gain more performance, image throughput, storage capacity, and also security and replication features
[Azure Container Registry service tiers](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-skus)

### ACR Authentication and Security Options
Azure Container Registry requires authentication for all operations. Azure Container Registry supports two types of identities for logging in, Azure Active Directory Identities, including both user and service principals, and a service‑specific ACR admin account. This is an administrative account which is disabled by default and is only needed in some scenarios. When building pipelines and automation, container orchestrators, the tools and applications should use what's called headless authentication for their unattended logins into ACR. Headless authentication is only supported using Azure Active Directory Identities, and we're going to focus on service principals in this module. You should not use the ACR admin account for headless authentication by tools or container orchestrators. From a user or developer experience standpoint, at the command line you can use az acr login or docker login to log into Azure Container Registry. You will be challenged for a username and password, and then you will be able to log into ACR and perform operations. The credential that you will use is your Azure AD identity. When it comes to which operations you can perform, that's where role‑based access controls come into play, and we're going to look into those in more detail in a moment. For a deeper dive into ACR security and the various supported authentication scenarios, check out this link here. Access to Azure Container Registry using an Azure Active Directory identity is role based, and identities can be assigned one of several predefined roles, and if needed, you can create custom roles. This is a listing of the predefined RBAC roles in Azure Container Registry. The roles here can be grouped into two use cases, roles assigned to people and roles assigned to tools, pipelines, or orchestrators using headless authentication via service principals. For example, the role's owner, contributor, and reader are all roles that you want to assign to Container Registry users based on the required access levels. These roles have access to both Azure Container Registry as an Azure resource and can administer or access its configuration using Azure tools. These roles also have access to the contents of the container registry itself, such as the images stored in it. The roles AcrPush, AcrPull, and AcrDelete are roles that you'll want to assign to service principals when using headless authentication for tools or container orchestrators. These roles have access to the container registry data such as images but do not have access to Azure Resource Manager, so they don't have access with Azure tools such as the Azure portal, Azure CLI, and Azure PowerShell. The primary example of the right role for headless authentication for a container orchestrator or with Azure container instances is AcrPull. This role gives those services the rights to pull an image, but no other access to the container registry or the data in it.
[Authenticate with an Azure container registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication?tabs=azure-cli)

[Azure Container Registry roles and permissions](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-roles?tabs=azure-cli)

### Creating and Authenticating to Azure Container Registry
To create an Azure Container Registry, we can use all of our normal deployment tools Azure portal, Azure PowerShell, and Azure CLI. Let's walk through an Azure CLI example to see this in action. First, to make our code slightly more usable, I'm going to set an environment variable, *ACR_NAME*. This will be our Azure Container Registry name. This name needs to be globally unique inside of Azure because it becomes part of the fully qualified domain name that we'll use to access this Azure Container Registry. 
To create an Azure Container Registry, use the command az acr create. Then you specify a resource group name. Here we're going to go with *psdemo‑rg*. 
Next, we give our container registry a name with the *‑‑name* parameter, and we'll references our *ACR_NAME* environment variable that we just set. 
Also required is a *SKU*, and we're going to go with *Standard* here. 
Now to log into the container registry that we just deployed, we can use *az acr login* and then specify the name parameter and then the *ACR_NAME* itself. 
This will log you in with your current Azure CLI credentials in your current session, which will have administrative access to the container registry since you just created it. 

```powershell
ACR_NAME='psdemoacr' #<---- THIS NEEDS TO BE GLOBALLY unique in Azure
az acr create \
--resource-group psdemo-rg \
--name $ACR_NAME \
--sku Standard

az acr login --name $ACR_NAME
```

### Pushing an Image into ACR
So now that we have a container image built on our local development workstation and a container registry deployed in Azure, it's time to push that container image into Azure Container Registry. 
And we're going to use two different methods here, first using Docker tools and then second using ACR tasks. And let's look at the code to do that. 
First, we'll load up an *ACR_NAME* environment variable again so that we can reuse that in our code. Then next, we need to get the login server for our Azure Container Registry. The login server is the public DNS name, specifying the network location of our Azure Container Registry. We can get this in the Azure portal by looking at the properties for our Azure Container Registry, but we can also retrieve it at the command line with *az acr show*, specifying the container registry name. We can then use the query parameter to extract the loginServer field. That value will then be stored in the environment variable *ACR_LOGINSERVER*. The current value for the login server in our example is going to be *psdemoacr.azurecr.io*. And so that's a combination of our Azure Container Registry name, which is *psdemoacr*, and the domain suffix, *azurecr.io*, which is the domain suffix for all Azure container registries. 
Next, we need to add an alias to our local container image using this login server and a new name and tag. This additional tag tells Docker where it needs to send the image when we execute a docker push. And to create an alias we can do that with docker tag *webappimage:v1*. That's our local container image that we built earlier in this module. For the target image for the alias, we're referencing the *ACR_LOGINSERVER* variable again and then appending an image name and tag. And so in our example here, that's going to be *psdemoacr.azurecr.io/webappimage:v1*. Docker tag just tags the image with an alias. Now we need to push the image into ACR, and we do that with docker push. We then specify the image alias that we just created together. When this is executed, it will then upload, or push, the image into ACR, and it will be available to be pulled down by authenticated users or services. What we just covered so far is one way to build and push an image using Docker tools. 


```powershell
ACR_NAME='psdemoacr'
ACR_LOGINSERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
#psdemoacr.azurecr.io

docker tag webappimage:v1 $ACR_LOGINSERVER/webappimage:v1
docker push $ACR_LOGINSERVER/webappimage:v1
```

We can build and push an image using ACR tasks. Using an ACR task to build our container image will read the Dockerfile into the current working directory and then zip up all the resources and code and then upload that into ACR to build our container image in Azure Container Registry. Once the build is finished, it'll then be pushed into ACR for us to use. 
We can use the command *az acr build* with the parameter *‑‑image*. This is what the image will be named and tagged with in Azure Container Registry. And so here we have *webappimage:v1‑acr‑task*. 
We then specify the name of the registry that we want to push the image to when the build is finished with the *‑‑registry* parameter and then specifying the *ACR_NAME*. We see a space and then a dot. This is going to reference a local Dockerfile in that current working directory.

```powershell
#Build using ACR Tasks
az acr build --image "webappimage:v1-acr-task" --registry $ACR_NAME .
```

#### Demo: Creating an Azure Container Registry
```powershell
#Login interactively and set a subscription to be the current active subscription
az login
az account set --subscription "Demonstration Account"


#Step 0 - Create Resource Group for our demo if it doesn't exist 
az group create \
    --name psdemo-rg \
    --location centralus


#Step 1 - Create an Azure Container Registry
#SKUs include Basic, Standard and Premium (speed, replication, adv security features)
#https://docs.microsoft.com/en-us/azure/container-registry/container-registry-skus#sku-features-and-limits
ACR_NAME='psdemoacr'  #<---- THIS NEEDS TO BE GLOBALLY unique inside of Azure
az acr create \
    --resource-group psdemo-rg \
    --name $ACR_NAME \
    --sku Standard 


#Step 2 - Log into ACR to push containers...this will use our current azure cli login context
az acr login --name $ACR_NAME
 

#Step 3 - Get the loginServer which is used in the image tag
ACR_LOGINSERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
echo $ACR_LOGINSERVER


#Step 4 - Tag the container image using the login server name. This doesn't push it to ACR, that's the next step.
#[loginUrl]/[repository:][tag]
docker tag webappimage:v1 $ACR_LOGINSERVER/webappimage:v1
docker image ls $ACR_LOGINSERVER/webappimage:v1
docker image ls


#Step 5 - Push image to Azure Container Registry
docker push $ACR_LOGINSERVER/webappimage:v1


#Step 6 - Get a listing of the repositories and images/tags in our Azure Container Registry
az acr repository list --name $ACR_NAME --output table
az acr repository show-tags --name $ACR_NAME --repository webappimage --output table


####
#We don't have to build locally then push, we can build in ACR with Tasks.
####

#Step 1 - use ACR build to build our image in azure and then push that into ACR
az acr build --image "webappimage:v1-acr-task" --registry $ACR_NAME .


#Both images are in there now, the one we built locally and the one build with ACR tasks
az acr repository show-tags --name $ACR_NAME --repository webappimage --output table
```


## V. Run containers by using Azure Container Instances
Azure Container Instances gives you a serverless Platform as a Service offering, enabling you to run containers in Azure without having to set up any virtual machines or other infrastructure services. It's most effectively used for simple applications, task automation, and also build jobs. When you need full container orchestration, you should look towards Azure Kubernetes Service. 
When you deploy containers in Azure Container Instances, you can access your applications over the internet via an automatically provisioned, fully qualified domain name. Or optionally, containers deployed in ACI can be connected directly to an Azure Virtual Network for private, secure communications. This can be combined with ExpressRoute or VPN gateway for access from other networks outside of Azure. 
When defining your containers in ACI, you can specify an amount of CPU or memory needed to run your application. The default is 1 core and 1.5 GB of RAM. 
If your ACI‑deployed containers need persistent data for data files or even databases, containers can directly mount Azure file shares backed by Azure Storage. 
Azure Container Instances also supports scheduling of multi‑group containers that share a host machine, local network, storage, and lifecycle. This enables you to combine your main application container with other supporting containers such as logging sidecars to construct more complex application scenarios. 
You can also define a container restart policy. Container restart policy tells ACI what to do if an application running inside of the container stops. And your options are restart always, restart on failure, and restart never. Always will restart the container if the application running inside the container stops for whatever reason, and this is a default option if you don't specify a restart policy when you deploy your container. The next option is on failure, which if the application running inside the container fails, then it will be automatically restarted by ACI. However, if the application exits gracefully, then the container will stop and not be restarted. And the final option is never, which when the application container stops, regardless of how it stopped, gracefully or ungracefully, the container will not be restarted. 
You can deploy containers into ACI from various container registries. You can deploy containers from Azure Container Registry, additionally, you can also deploy containers into ACI from any Docker compliant container registry, including Docker Hub. When deploying containers, you can use both public or private container registries. 
A private container registry is one that requires authentication or is not directly attached to the internet. In fact, the Azure Container Registry that we just deployed and pushed the container image into requires authentication by default. To authenticate to our Azure Container Registry, we need to tell Azure Container Instances two key elements when we deploy, the network location of the login server for our container registry, and the second element that we need is the authentication credentials, specifically a username and password that has the appropriate role‑based access control rights to pull an image from our container registry. 

### Creating a Service Principal for ACI to Pull From ACR

Let's walk through the code needed to create a service principal that will have access to pull images from our Azure Container Registry. 
First up, we'll define ACR_NAME, that's the actual name of our container registry, and I'm using psdemoacr, which is the name of the container registry that we deployed earlier. 
Now for the next variable, we have to get the actual resource ID of our Azure Container Registry. 
Next, we'll define a variable for service principal name and then use *az ad sp create‑for‑rbac* to create the service principal and then retrieve its password and store that in the variable SP_PASSWD. Going through the parameters for this command, first up, we have name, which is going to be the name of our service principal. We then have scopes, which is going to be the container registry ID. And then the role is acrpull. This is the role‑based access control role that allows orchestrators like ACI to pull images from ACR. 
Then next, we'll use the query parameter to retrieve the password field, and then we'll modify the output and set that to tsv. This code will then execute and store that password in the variable SP_PASSWD. And this is the password that we'll use when authenticating to our Azure Container Registry. 
Next, we need to get the app ID of the service principal, which we'll use as the username when authenticating to our Azure Container Registry. And we can do that with *az ad sp show*. And then we'll specify the service principal name for the ID parameter. We'll then use the query parameter to get the appId, and then we'll modify that output to tsv, and then the output of that command will be stored into the variable SP_APPID. Again, app ID will be used as the username when authenticating to our Azure Container Registry. Now, we're using environment variables here in our scripts for deployment. If needed, the service principal app ID and the password can be stored in Azure Key Vault as secrets for secure access and reuse.

```powershell
ACR_NAME='psdemoacr'
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query id --output tsv)

SP_NAME=acr-service-principal
SP_PASSWD=$(az ad sp create-for-rbac \
--name http://$ACR_NAME-pull \
--scopes $ACR_REGISTRY_ID \
--role acrpull \
--query password \
--output tsv)

SP_APPID=$(az ad sp show \
--id http://$ACR_NAME-pull \
--query appId \
--output tsv)
```

### Running a Container from ACR in ACI
With the appropriate security laid out, allowing Azure Container Instances to pull from Azure Container Registry, we can now tell Azure Container Instances how to deploy a container from our Azure Container Registry using authentication. 
First, we'll set an environment variable for our loginServer. This will be used to tell Azure Container Instances the network location of where our container images are stored and also used in conjunction with the service principal app ID and password to authenticate to our Azure Container Registry. 
Now, to create a container in ACI, we use az container create. We'll then specify the resource‑group that we want to deploy into. We'll then give our container a name, and this is going to be used to uniquely identify the resource inside of Azure. When it comes to accessing the container application, you will use the dns‑name‑label parameter to provide a hostname for the container. Here, we're using psdemo‑webapp‑cli for both the container name and the dns‑name‑label. The dns‑name‑label is used as part of the fully‑qualified domain name for the network location to access the container. The format of the FQDN is the dns‑name‑label, which for this deployment is psdemo‑webapp‑cli, and then for a subdomain, we have the region name, which is centralus. For the base domain, that's always going to be azurecontainer.io, and so the dns‑name‑label must be unique within a region. 
Then next, you'll define the ports you have your application listening on. And so here, we're going to use port 80. Now, for the image parameter, this is going to define the fully‑qualified path to the location of our container image. And so here, we see the ACR_LOGINSERVER variable again, which we sat at the top of the code here. We then specify the image and the tag that we want to run. And so here, we're going to run the webappimage with the tag of v1. This is the container that we built together and pushed into ACR using Docker tools. Now, we need to tell ACI how to authenticate to our Azure Container Registry, and we can do that with the parameter registry‑login‑server. Here, we're going to specify the ACR_LOGINSERVER variable. We'll then specify a registry‑username, and there, we see it's going to be the service principal app ID that we retrieved on the previous slide. And then for the registry‑password, that would be the service principal password. And so the key here for authenticating to a container registry is these three last parameters, the network location of the login server, the registry‑username, which is our service principal app ID, and the registry‑password, which is our service principal's password. If the container registry did not require authentication, we could omit these three parameters.

```powershell
ACR_LOGINSERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

az container create \
--resource-group psdemo-rg \
--name psdemo-webapp-cli \
--dns-name-label psdemo-webapp-cli \
--ports 80 \
--image $ACR_LOGINSERVER/webappimage:v1 \
--registry-login-server $ACR_LOGINSERVER \
--registry-username $SP_APPID \
--registry-password $SP_PASSWD
psdemo
```

#### Demo - Deploying containers in Azure Container Instances using Azure Portal
Container instaces -> Add
![](images/container-instances-1.png)
![](images/container-instances-2.png)
![](images/container-instances-3.png)


#### Demo - Deploying containers in Azure Container Instances using Azure CLI
```powershell
#Login interactively and set a subscription to be the current active subscription
az login
az account set --subscription "Demonstration Account"


#Demo 0 - Deploy a container from a public registry. dns-name-label needs to be unique within your region.
az container create \
    --resource-group psdemo-rg \
    --name psdemo-hello-world-cli \
    --dns-name-label psdemo-hello-world-cli \
    --image mcr.microsoft.com/azuredocs/aci-helloworld \
    --ports 80


#Show the container info
az container show --resource-group 'psdemo-rg' --name 'psdemo-hello-world-cli' 


#Retrieve the URL, the format is [name].[region].azurecontainer.io
URL=$(az container show --resource-group 'psdemo-rg' --name 'psdemo-hello-world-cli' --query ipAddress.fqdn | tr -d '"') 
echo "http://$URL"




#Demo 1 - Deploy a container from Azure Container Registry with authentication
#Step 0 - Set some environment variables and create Resource Group for our demo
ACR_NAME='psdemoacr' #<---change this to match your globally unique ACR Name


#Step 1 - Obtain the full registry ID and login server which well use in the security and create sections of the demo
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query id --output tsv)
ACR_LOGINSERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

echo "ACR ID: $ACR_REGISTRY_ID"
echo "ACR Login Server: $ACR_LOGINSERVER"


#Step 2 - Create a service principal and get the password and ID, this will allow Azure Container Instances to Pull Images from our Azure Container Registry
SP_PASSWD=$(az ad sp create-for-rbac \
    --name http://$ACR_NAME-pull \
    --scopes $ACR_REGISTRY_ID \
    --role acrpull \
    --query password \
    --output tsv)

SP_APPID=$(az ad sp show \
    --id http://$ACR_NAME-pull \
    --query appId \
    --output tsv)

echo "Service principal ID: $SP_APPID"
echo "Service principal password: $SP_PASSWD"


#Step 3 - Create the container in ACI, this will pull our image named
#$ACR_LOGINSERVER is psdemoacr.azurecontainer.io. this should match *your* login server name
az container create \
    --resource-group psdemo-rg \
    --name psdemo-webapp-cli \
    --dns-name-label psdemo-webapp-cli \
    --ports 80 \
    --image $ACR_LOGINSERVER/webappimage:v1 \
    --registry-login-server $ACR_LOGINSERVER \
    --registry-username $SP_APPID \
    --registry-password $SP_PASSWD 


#Step 4 - Confirm the container is running and test access to the web application, look in instanceView.state
az container show --resource-group psdemo-rg --name psdemo-webapp-cli  


#Get the URL of the container running in ACI...
#This is our hello world app we build in the previous demo
URL=$(az container show --resource-group psdemo-rg --name psdemo-webapp-cli --query ipAddress.fqdn | tr -d '"') 
echo $URL
curl $URL


#Step 5 - Pull the logs from the container
az container logs --resource-group psdemo-rg --name psdemo-webapp-cli


#Step 6 - Delete the running container
az container delete  \
    --resource-group psdemo-rg \
    --name psdemo-webapp-cli \
    --yes


#Step 7 - Clean up from our demos, this will delete all of the ACIs and the ACR deployed in this resource group.
#Delete the local container images
az group delete --name psdemo-rg --yes
docker image rm psdemoacr.azurecr.io/webappimage:v1
docker image rm webappimage:v1
```