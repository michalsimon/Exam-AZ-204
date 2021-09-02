# I. Implementacja rozwiązań Infrastructure as a service

**Implementacja rozwiązań IaaS** jest częścią tematu **Develop Azure compute solutions** egzaminu **AZ-204**.

Umiejętności badane w tej części egzaminu:
* Udostępnianie maszyn wirtualnych (**VM**)
* Konfiguracja, walidacja i wdrażanie **szablonów ARM**
* Konfiguracja obrazów kontenerów 
* Publikacja obrazów w **Azure Container Registry**
* Uruchamianie kontenerów za pomocą **Azure Container Instance**

## 1. Udostępnianie maszyn wirtualnych
Zacznijmy od ogólnego przeglądu tego, z czego składa się maszyna wirtualna.
Maszyny wirtualne platformy Azure (**VMs**) są wdrażane w **grupach zasobów** i znajdują się w **regionach** platformy Azure. Zwykle chcemy umieścić maszynę wirtualną w **regionie** blisko aplikacji lub użytkowników, którzy będą korzystać z usług wdrożonych na tej maszynie wirtualnej.
Podczas budowania maszyny wirtualnej wybieramy spośród wstępnie skonfigurowanych **rozmiarów maszyn wirtualnych** na podstawie liczby rdzeni procesora, ilości pamięci RAM, a także różnych możliwości wydajności dysku. Wybrany rozmiar zależy od obciążenia wdrażanego na tej maszynie wirtualnej. Rozmiar maszyny wirtualnej można łatwo zaktualizować lub obniżyć po wdrożeniu maszyny wirtualnej. 
Kolejnym kluczowym elementem wdrażania maszyny wirtualnej jest **połączenie sieciowe** maszyny wirtualnej z resztą środowiska i w razie potrzeby z Internetem. Kolejnym składnikiem maszyny wirtualnej są **obrazy maszyn wirtualnych**. Obrazy są podstawowym obrazem używanym do wdrażania na naszej maszynie wirtualnej, najczęściej systemów operacyjnych, takich jak Windows lub Linux. W portalu *Azure Marketplace* dostępnych jest wiele różnych obrazów maszyn wirtualnych opartych na wielu różnych systemach operacyjnych z róznymi edycjami, obrazy ze wstępnie skonfigurowanymi aplikacjami oraz sieciowe urządzenia wirtualne. 
Ostatnim składnikiem maszyny wirtualnej jest **pamięć masowa**. Każda utworzona maszyna wirtualna będzie miała co najmniej jeden dysk wirtualny do obsługi podstawowego systemu operacyjnego. W razie potrzeby można dodać dodatkowe dyski wirtualne w celu obsługi danych aplikacji. 

#### Metody tworzenia maszyn wirtualnych na platformie Azure:
Podczas tworzenia maszyny wirtualnej na platformie Azure mamy do dyspozycji kilka narzędzi:
* **Azure Portal** 
* **Azure CLI** 
* **Azure PowerShell (Az Module)**
* **Azure ARM Templates**

### 1.1 Tworzenie maszyny wirtualnej w portalu Azure
Aby utworzyć **maszynę wirtualną** w portalu Azure należy przejść do usługi **Maszyny Wirtualne** i wcisnąć guzik **utwórz maszynę wirtualną**.
Na stronie tworzenie maszyny wirtualnej pierwsza sekcja to informacje **Podstawowe** o tworzonej maszynie. Na górze strony można zobaczyć, że istnieją dodatkowe sekcje dotyczące dysków, sieci, zarządzania itp. Te sekcje umożliwiają tworzenie bardziej niestandardowych konfiguracji, takich jak dodawanie dodatkowych dysków lub dodawanie maszyny wirtualnej do istniejącej sieci wirtualnej, a nawet tworzenie bardziej szczegółowych reguł zabezpieczeń sieci.

![](pic/vm-portal-details-1.png)

W sekcji **Podstawowe** przypisujemy tworzoną maszynę wirtualną do **subskrypcji** i do **grupy zasobów**. Jeśli **grupa zasobów** nie istnieje to można ją utworzyć. 
Następnie definiujemy szczegóły instancji, w której nadajemy maszynie wirtualnej **nazwę** i wybieramy **region**, w którym chcemy wdrożyć maszynę wirtualną. Następnie, opcjonalnie, możemy określić zestawy i strefy dostępności. Następnie wybierzemy **obraz maszyny wirtualnej** z listy obrazów dostępnych w wybranym regionie.

Kolejna opcja to **Azure Spot**, która pozwala na użycie maszyny w obniżonej cenie lecz umożliwia platformie Azure zatrzymanie i zwolnienie maszyny wirtualnej, jeśli platforma Azure z dowolnego powodu potrzebuje z powrotem tej pojemności obliczeniowej.

Następnie definiujemy **rozmiar maszyny wirtualnej**, w przypadku tej demonstracji wybieramy najniższy z naszej listy rozmiarów maszyn wirtualnych dostępnych w regionie.

![](pic/vm-portal-details-2.png)

W sekcji **Konto administratora** definiujemy wymagane informacje dotyczące dostępu administracyjnego do maszyny wirtualnej. W systemie Windows jest to nazwa użytkownika i hasło, a w systemie Linux może to być nazwa użytkownika i hasło lub klucz publiczny SSH.

Na koniec definiujemy kilka **reguł portów przychodzących**, aby uzyskać dostęp do tej maszyny wirtualnej. W konfiguracji domyślnej maszyna wirtualna otrzyma publiczny adres IP w celu uzyskania dostępu do tej maszyny wirtualnej przez Internet. Ale domyślnie dostęp spoza sieci wirtualnej lub Internetu nie jest dozwolony. Dodanie tutaj reguł portów przychodzących jest sposobem na zezwolenie na dostęp sieciowy do maszyny wirtualnej poprzez określenie, które porty przychodzące chcemy otworzyć. Wybranie portu przychodzącego w tym miejscu doda regułę do grupy zabezpieczeń sieci, umożliwiając dostęp z dowolnego adresu IP na określonym porcie. Ponieważ jest to maszyna wirtualna Windows i chcemy uzyskać do niej zdalny dostęp, otworzymy protokuł RDP na porcie 3389. Pozwoli to na dostęp RDP do tej maszyny wirtualnej na tym porcie z dowolnego adresu IP. Możemy również dodać inne porty, takie jak 80 dla HTTP, 443 dla HTTPS i port 22 dla dostępu SSH do maszyny wirtualnej.

Dane do wprowadzenia w sekcji **Podstawowe**:

| Sekcja       | Wartość       |
|:----------------|:---------------|
| Subskrypcja | *{subscription_name}* |
| Grupa zasobów | *(new) iaas-demo-rg* |
| Nazwa maszyny wirtualnej | *iaas-demo-win* |
| Region | *Europa Zachodnia* |
| Opcje dostępności | *Nie jest wymagana żadna nadmiarowość infrastruktury* |
| Obraz | *Windows server 2019 Datacenter - Gen1* |
| Rozmiar | *Standard_DS1_v2* |
| Username | *iaas-demo-win-user* |
| Password | *{jakieś-hasło}* |
| Publiczne porty ruchu przychodzącego | *Zezwalaj na wybrane porty* |
| Wybierz porty wejściowe | *RDP (3389)* |
| **Przeglądanie + tworzenie** |  |

**Widok w trakcie wdrażania maszyny:**
![](pic/vm-portal-success.png)

**Widok detali utworzonej maszyny wirtualnej:**
![](pic/vm-portal-vm-view.png)

Aby połączyć się do maszyny za pomocą protokołu RDP wybieramy guzik **Połącz** z górnego menu na stronie detali maszyny wirtualnej i pobieramy plik RDP:
![](pic/vm-portal-vm-view-rdp-connect.png)

### 1.2 Tworzenie maszyny wirtualnej w kodzie