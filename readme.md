### Opis
Zbiór skryptów do automatyzacji tworzenia wyborów w [Zeusie](https://github.com/pwmarcz/zeus).

### Użycie:
1. Przygotuj dane wsadowe w pliku zeus-input.csv
1. Uruchom ```zeus-create.ps1```
1. Opcjonalnie, podaj dane logowania do zeusa i panelu
1. gdy powierniczki wyborów wygenerują swoje klucze, uruchom ```zeus-finalize.ps1```
1. Opcjonalnie, pobierz wyniki i wygeneruj uchwały za pomocą ```zeus-getResults.ps1```

### struktura zeus-input.csv

* Election - Nazwa wyborów
* Start - Data startu w formacie YYYY-MM-DD
* End - Data konca w formacie YYYY-MM-DD
* Poll - Nazwa głosowania
* Seats - ilość mandatów
* M - Kandydatury z kwoty męskiej, rozdzielone średnikami
* K - Kandydatury z kwoty żeńskiej, rozdzielone średnikami
* ID - ID okręgu z panelu

### Wartości domyślne
Wybory zaczynają się o 00:00 i kończą o 23:59
Kandydatury są wyświetlane na karcie do głosowania w losowej kolejności
Kwoty wynoszą połowę ilości mandatów zaokrągloną w górę.
Typ wyborów to STV

Przetestowane na Powershell Core 6, platforma Windows
