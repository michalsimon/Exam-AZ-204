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