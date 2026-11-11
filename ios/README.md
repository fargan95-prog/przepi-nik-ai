# Przepiśnik AI — natywny iOS

Pierwszy etap projektu: aplikacja SwiftUI i rozszerzenie Share Extension.

## Wymagania
- macOS z Xcode 15+
- XcodeGen
- konto Apple Developer do instalacji na urządzeniu i dystrybucji
- skonfigurowane App Group: `group.com.fargan95.przepisnikai`

## Generowanie projektu
W katalogu `ios` uruchom `xcodegen generate`, otwórz `PrzepisnikAI.xcodeproj` i wybierz właściwy Team oraz Bundle Identifier. Skonfiguruj App Group identycznie dla aplikacji i rozszerzenia.

## Aktualny zakres
- natywna aplikacja SwiftUI
- Share Extension odbierające URL, tekst, obrazy i pliki wideo przekazane przez system iOS
- zapis odebranych danych we współdzielonym kontenerze App Group
- podstawowy ekran importu i prezentacja odebranego materiału

## Ważne ograniczenie Instagrama
Instagram może przekazać wyłącznie adres URL, a nie sam plik rolki. Rozszerzenie zapisuje dokładnie to, co otrzyma od systemu. Prywatnych treści ani niedostępnych multimediów nie próbuje obchodzić. Następny etap obejmuje backend AI, analizę plików i obsługę linków publicznych zgodną z zasadami platform.

## Bezpieczeństwo
Klucze API przechowujemy wyłącznie po stronie backendu. Nie umieszczamy ich w aplikacji iOS ani w repozytorium.
