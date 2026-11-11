# Przepiśnik AI — aplikacja iOS

Natywna aplikacja SwiftUI z rozszerzeniem udostępniania i backendem AI.

## Funkcje aplikacji
- Import materiałów z systemowego arkusza udostępniania iOS: tekst, linki, zdjęcia, zrzuty ekranu i filmy.
- Analiza zdjęć przez model AI oraz analiza klatek filmu i transkrypcja ścieżki audio, jeśli film ją zawiera.
- Tworzenie kart przepisów po polsku z nazwą, opisem, kategorią, porcjami, czasem, składnikami i krokami.
- Oznaczanie brakujących lub niepewnych danych — aplikacja nie powinna dopowiadać ilości ani składników.
- Lokalna biblioteka, wyszukiwarka, filtrowanie kategorii, edycja, usuwanie i udostępnianie kart.
- Ręczne dodawanie przepisów.

## Wymagania do zbudowania i instalacji
- macOS i Xcode 15 lub nowszy.
- XcodeGen.
- Apple Developer account / provisioning dla instalacji na fizycznym iPhonie.
- App Group skonfigurowana w Apple Developer dla obu identyfikatorów:
  - `com.fargan95.przepisnikai`
  - `com.fargan95.przepisnikai.share`
- Ten sam App Group: `group.com.fargan95.przepisnikai`.

## Generowanie projektu
W katalogu repozytorium:

```bash
cd ios
xcodegen generate
open PrzepisnikAI.xcodeproj
```

W Xcode wybierz swój Team dla obu targetów i skonfiguruj provisioning. Następnie uruchom target `PrzepisnikAI` na symulatorze lub iPhonie. Rozszerzenie Share powinno być osadzone w aplikacji.

## Automatyczna kontrola kompilacji
Workflow GitHub Actions w `.github/workflows/ios-build.yml` generuje projekt Xcode i buduje aplikację dla iOS Simulator. Nie podpisuje aplikacji i nie publikuje jej w App Store.

## Backend
Backend znajduje się w `native-backend` i jest wdrażany jako osobna usługa. W Render należy ustawić:
- `OPENAI_API_KEY` — klucz przechowywany wyłącznie po stronie serwera.
- Opcjonalnie `OPENAI_MODEL` — domyślnie `gpt-4o-mini`.

Endpoint zdrowia: `/health`.
Import przepisu: `POST /v1/recipes/import` (multipart: `text`, `sourceURL`, `files`).

## Ograniczenie Instagrama
Instagram może przekazać wyłącznie URL zamiast pliku lub opisu rolki. Sam link nie daje aplikacji dostępu do prywatnej zawartości. W takim przypadku aplikacja zachowuje źródło i prosi o udostępnienie zrzutów ekranu, pliku albo wklejenie opisu. Aplikacja nie obchodzi zabezpieczeń Instagrama ani nie pobiera treści z prywatnych kont.

## Prywatność i bezpieczeństwo
- Klucz OpenAI pozostaje na backendzie, nie jest umieszczany w aplikacji.
- Biblioteka przepisów jest przechowywana lokalnie w App Group na urządzeniu.
- Materiały wysłane do analizy są przekazywane do skonfigurowanego backendu i usługi AI.
- Przed publikacją należy dodać politykę prywatności opisującą przetwarzanie materiałów i danych.
