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
Plik **Dockerfile** używany przez program *Visual Studio* jest podzielony na wiele etapów. Ten proces opiera się na funkcji wieloetapowej kompilacji platformy *Docker*.

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

### Azure Container Registry (ACR)
**Azure Container Registry** to zarządzana usługa **Docker Registry**, która umożliwia tworzenie i przechowywanie oraz zarządzanie obrazami kontenerów. 
**ACR** może być podstawowym składnikiem potoku *CI/CD*. Można go zintegrować z systemami kontroli wersji (np. *Git*) i tworzyć obrazy kontenerów po zatwierdzeniu kodu. 

Ponadto usuługi orkiestrujące kontenery jak np **Kubernetes** czy **Azure Container Instances** mogą zostać skonfigurowane do pobierania obrazów z **Azure Container Registry**. 

Ponadto można użyć zadań **Azure Container Registry** aby usprawnić tworzenie, testowanie, wypychanie i wdrażanie obrazów na platformie **Azure**. **ACR Tasks** wykonuje proces kompilacji obrazu w **Azure Container Registry** i może zostać wyzwolony w celu zbudowania obrazu kontenera, gdy kod źródłowy aplikacji zostanie zatwierdzony w systemie kontroli wersji. Po zakończeniu zadania obraz zostanie automatycznie przesłany do **ACR**.
Istnieje kilka poziomów wersji usługi **ACR**. Obecne poziomy usługi to **Basic**, **Standard** i **Premium**. Im wyższa wersja tym większa wydajność, przepustowość obrazu, pojemność magazynu, a także funkcje zabezpieczeń i replikacji. Więcej na ten temat na stronie [Azure Container Registry service tiers](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-skus).

### Uwierzytelnianie ACR
**Azure Container Registry** wymaga uwierzytelniania dla wszystkich operacji i obsługuje kilka typów uwierzytelniania tożsamości, z których każdy ma zastosowanie do innego scenariusza użycia rejestru.
Wszystkie typy uwierzytelniania dostępne są na stronie [Authenticate with an Azure container registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication?tabs=azure-cli).

Rekomendowanym sposobem uwierzytelnienia jest uwierzytelnienie z użyciem indywidualnego loginu lub za pomocą uwierzytelniania beznagłówkowego (ang. headless authentication), które używają usługi **Azure Active Directory Identities**. 
Istnieje również specyficzne dla usługi konto administratora **ACR**, które jest domyślnie wyłączonym kontem administracyjnym i jest potrzebne tylko w niektórych scenariuszach.

Podczas tworzenia potoków CI/CD, orkiestratorów kontenerów i innych narzędzi automatyzacji powinno się używać tak zwanego uwierzytelniania beznagłówkowego (ang. headless authentication).

Jako deweloper, aby zalogować się do **Azure Container Registry**, można użyć logowania **AZ ACR** lub loginu platformy *Docker* z wiersza polecenia. Po zalogowaniu loginem i hasłem usługi **Azure AD Identity** można wykonywać operacje na które pozwala kontrola dostępu oparta na rolach.

Lista wbudowanych ról w **Azure Container Registry** dostępna jest na stronie [Azure Container Registry roles and permissions](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-roles?tabs=azure-cli).

Role te zwykle przypisujemy do osób lub narzędzi. Zwykle role **Owner**, **Contributor** i **Reader** są przypisywane użytkownikom ponieważ mają dostęp zarówno do **ACR** jako zasobu platformy Azure, jak i do administrowania lub uzyskiwania dostępu do jego konfiguracji oraz dostęp do zawartości samego rejestru.
Role **AcrPush**, **AcrPull** i **AcrDelete** zwykle przypisujemy do narzędzi automatyzacji. Mają one dostęp tylko do danych rejestru kontenerów.

### Tworzenie i logowanie do ACR
Rejest **ACR** możemy utworzyć za pomocą zwykłych narzędzi narzędzi do wdrażania np. **Azure Portal**, **Azure PowerShell** lub **Azure CLI**.

Tworzenie rejestru **ACR** odbywa się z użyciem polecenia `az acr create` które jako parametry wejściowe pobiera nazwę grupy zasobów, nazwę rejestru która musi być unikalna na platformie Azure oraz SKU. 

Aby zalogować się do utworzonego rejestru kontenerów używamy polecenia `az acr login`z nazwą rejestru jako parametrem. Spowoduje to zalogowanie się przy użyciu bieżących poświadczeń wiersza polecenia platformy Azure w bieżącej sesji, które będą miały dostęp administracyjny do rejestru kontenerów od momentu jego utworzenia.

```powershell
#ACR registry name environment variable
$ACR_REGISTRY_NAME='iaasdemoacr' 

az acr create `
--resource-group iaas-demo-rg `
--name $ACR_REGISTRY_NAME `
--sku Standard

az acr login --name $ACR_REGISTRY_NAME
```

### Wypychanie obrazu do ACR
Po zbudowaniu obrazu kontenera na lokalnej stacji roboczej i wdrożeniu rejestru kontenerów **ACR**, możemy wypchnąć obraz kontenera do rejestru. Można do tego użyć narzędzi *Docker* lub **ACR Tasks**.

#### Wypychanie obrazu do ACR za pomocą narzędzi Docker
Aby użyć narzędzi Docker musimy pierw uzyskać publiczną nazwę DNS dla naszego rejestru **ACR**. Możemy to pobrać w portalu Azure lub z wiersza polecenia za pomocą polecenia `az acr show` z nazwą rejestru jako parametrem wejściowym. Aby wyodrębnić pole *loginServer* używamy parametr `--query loginServer`.

Następnie nadajemy alias lokalnemu obrazowi przy użyciu polecenia `docker tag`. Jako parametry podajemy lokalny obraz kontenera i docelowy alias dla tego obrazu. 
Po nadaniu aliasu wypychamy obraz do rejestru za pomocą polecenia `docker push` używając aliasu obrazu docelowego jako parametru.

```powershell
#ACR registry name environment variable
$ACR_REGISTRY_NAME='iaasdemoacr' 

$ACR_LOGINSERVER=$(az acr show --name $ACR_REGISTRY_NAME --query loginServer --output tsv) echo $ACR_LOGINSERVER #iaasdemoacr.azurecr.io

docker tag dockerwebapp:v1 $ACR_LOGINSERVER/dockerwebapp:v1
docker push $ACR_LOGINSERVER/dockerwebapp:v1
```

#### Wypychanie obrazu do ACR za pomocą ACR Tasks
Użycie zadania **ACR Task** do zbudowania naszego obrazu spowoduje odczytanie pliku **Dockerfile** oraz spakowanie wszystkich zasobów i kodu, a następnie przesłanie ich do **ACR** w celu zbudowania obrazu.
Służy do tego polecenie `az acr build` z parametrem *‑‑image* i `--registry`. Kropka na końcu polecenia odnosi się do lokalnego pliku **Dockerfile** w bieżącym katalogu roboczym.

```powershell
#ACR registry name environment variable
$ACR_REGISTRY_NAME='iaasdemoacr' 

#Build using ACR Tasks
az acr build --image "dockerwebapp:v1-acr-task" --registry $ACR_REGISTRY_NAME .
```

### Kod demo:
Plik ze skryptem wdrożenia ACR dostępny jest tutaj:
[create-acr-by-azure-cli](https://github.com/michalsimon/Exam-AZ-204/blob/main/src/IaaS/create-acr-by-azure-cli.ps1)

## 3. Uruchamianie kontenerów za pomocą Azure Container Instance

**Azure Container Instances** to bezserwerowa platforma, która umożliwia uruchamianie kontenerów na platformie Azure bez konieczności konfigurowania jakichkolwiek maszyn wirtualnych lub innej infrastruktury. Najczęściej jest używana do prostych aplikacji i automatyzacji zadań. 
Po wdrażaniu kontenera w **ACI** aplikacja jest dostępnaza pośrednictwem automatycznie aprowizowanej, w pełni kwalifikowanej nazwy domenowej. Opcjonalnie kontenery wdrożone w **ACI** można połączyć bezpośrednio z siecią wirtualną platformy Azure w celu zapewnienia prywatnej, bezpiecznej komunikacji. 

Podczas definiowania kontenerów w **ACI** można określić ilość procesora lub pamięci potrzebnej do uruchomienia aplikacji. Domyślnie jest to 1 rdzeń i 1,5 GB pamięci RAM. Kontenery **ACI** mogą bezpośrednio instalować udziały plików **Azure Storage**.

**Azure Container Instances** obsługuje również łączenie kontenerów, które współużytkują maszynę hosta, sieć lokalną, magazyn danych i cykl życia. Umożliwia to łączenie głównego kontenera aplikacji z innymi kontenerami (ang. sidecar), w celu konstruowania bardziej złożonych scenariuszy aplikacji.

**ACI** umożliwia także na ustawienie zasad ponownego uruchamiania kontenera jeśli aplikacja działająca w kontenerze zostanie zatrzymana. Dostępne opcje to: zawsze restartuj, restartuj w przypadku niepowodzenia i nie restartuj nigdy. Domyślną opcją jest restartuj zawsze.

Kontenery **ACI** można wdrażać z **Azure Container Registry**, a także z dowolnego rejestru kontenerów zgodnego z platformą **Docker**, w tym z **Docker Hub**. Podczas wdrażania kontenerów można używać zarówno publicznych, jak i prywatnych rejestrów kontenerów.

Prywatny rejestr kontenerów to taki, który wymaga uwierzytelnienia lub nie jest bezpośrednio połączony z Internetem. **ACR** domyślnie wymaga uwierzytelniania. Podczas wdrażania kontenera z **ACR** musimy poinformować **ACI** o lokalizacji sieciowej serwera logowania naszego rejestru  i sposobie uwierzytelniania.

### Uwierzytelnianie usługi ACI do rejestru pobrania obrazów z ACR
Pierw definiujemy zmienną `$ACR_REGISTRY_NAME` która jest aktualną nazwą utworzonego wcześniej rejestru **ACR**, oraz zmienną `$SERVICE_PRINCIPAL_NAME` która jest nazwą użytkownika dla usługi **ACI**.

Następnie pobieramy identyfikator tego rejestru do zmiennej `$ACR_REGISTRY_ID` za pomocą polecenia `az acr show --name $ACR_REGISTRY_NAME --query id --output tsv`.
Następnie używamy polecenia `az ad sp create‑for‑rbac` do utworzenia użytkownika usługi po czym pobieramy jego hasło i zapisujemy do zmiennej `$SERVICE_PASSWD`. Tego hasła będziemu używali do dostępu do **ACR**. Parametrami tego polecenia są: `--name` oznaczający nazwę użytkownika dla usługi,`--scopes` oznaczający zakres dostępu i `--role` oznaczający rolę kontroli dostępu.

Następnie musimy uzyskać identyfikator aplikacji dla usługi **ACI**, którego będziemy używać jako nazwy użytkownika podczas uwierzytelniania w naszym **ACR**. Możemy to zrobić za pomocą polecenia `az ad sp list` z parametrem `--display-name` którego wartością jest nazwą użytkownika dla usługi **ACI**. Używając parametru zapytania uzyskujemy identyfikator aplikacji który zapisujemy do zmiennej `$SERVICE_PRINCIPAL_APPID`.

Pełny opis tworzenia użytkownika dla usługi **ACI** znajduje się na stronie [Azure Container Registry authentication with service principals](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-service-principal).

```powershell
# ACR_REGISTRY_NAME: The name of your Azure Container Registry
$ACR_REGISTRY_NAME='iaasdemoacr'
# SERVICE_PRINCIPAL_NAME: Must be unique within your AD tenant
$SERVICE_PRINCIPAL_NAME='acr-service-user'

# Obtain the full registry ID for subsequent command args
$ACR_REGISTRY_ID=$(az acr show --name $ACR_REGISTRY_NAME --query id --output tsv)

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
```

### Uruchamianie obrazu kontenera z ACR w ACI
Pierw definiujemy zmienną `$ACR_REGISTRY_NAME` która jest aktualną nazwą utworzonego wcześniej rejestru **ACR**, oraz zmienną `$ACR_LOGINSERVER` która jest lokalizacją sieciową rejestru **ACR** z obrazami kontenerów.

Tworzenie kontenera w **ACI** odbywa się przy użyciu poecenia `az container create` dla którego określamy grupę zasobów, nazwę kontenera, nazwę hosta dla kontenera, porty, ścieżkę do lokalizacji obrazu kontenera w **ACR** i sposób uwierzytelnienia a w tym serwer logowania, nazwa użytkownika i hasło. 

```powershell
# ACR_REGISTRY_NAME: The name of your Azure Container Registry
$ACR_REGISTRY_NAME='iaasdemoacr'

#Get the loginServer 
$ACR_LOGINSERVER=$(az acr show --name $ACR_REGISTRY_NAME --query loginServer --output tsv)

az container create `
--resource-group iaas-demo-rg `
--name iaas-demo-dockerwebapp `
--dns-name-label iaas-demo-dockerwebapp `
--ports 80 `
--image $ACR_LOGINSERVER/dockerwebapp:v1 `
--registry-login-server $ACR_LOGINSERVER `
--registry-username $SERVICE_PRINCIPAL_APPID `
--registry-password $SERVICE_PRINCIPAL_PASSWORD
```

### Kod demo:
Plik ze skryptem uruchamiania kontenerów za pomocą **ACI** dostępny jest tutaj: [deploy-acr-image-in-aci-by-azure-cli](https://github.com/michalsimon/Exam-AZ-204/blob/main/src/IaaS/deploy-acr-image-in-aci-by-azure-cli.ps1)