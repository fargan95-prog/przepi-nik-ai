# Przepiśnik AI — wdrożenie na iPhone/iPad (bez Maca)

## Co jest w paczce
- `index.html`, `styles.css`, `app.js` — aplikacja PWA
- `manifest.webmanifest`, `sw.js`, ikony — instalacja na ekranie początkowym i tryb offline
- `worker.js` — backend agenta AI dla Cloudflare Workers

Aplikacja zapisuje przepisy lokalnie w Safari/IndexedDB. iPhone i iPad mają osobne biblioteki. Nie ma synchronizacji między urządzeniami.

## Ważne przed uruchomieniem
1. Konto ChatGPT i API OpenAI to dwa osobne rozliczenia. Do agenta potrzebujesz klucza API z platform.openai.com oraz aktywnego rozliczania API.
2. Klucza OpenAI nie wolno wpisywać do aplikacji ani udostępniać w rozmowie. Umieść go wyłącznie jako sekret Cloudflare `OPENAI_API_KEY`.
3. Agent analizuje tekst, do 8 zdjęć/zrzutów ekranu i plik audio/wideo dostarczony z urządzenia. Sam link Instagram nie daje gwarantowanego dostępu do treści rolki.
4. AI może nie odczytać materiału, jeśli napisy są nieczytelne albo autor nie podał ilości. Brakujące ilości będą oznaczone jako „nie podano”, a nie zgadywane.

## Krok 1 — opublikuj aplikację PWA
Najprościej użyć Netlify Drop:
1. Na iPadzie otwórz Safari i zaloguj się do Netlify: https://app.netlify.com/drop
2. Rozpakuj ZIP w aplikacji Pliki.
3. Prześlij folder `przepisnik-pwa` (musi zawierać `index.html` bezpośrednio w środku folderu).
4. Netlify poda adres w rodzaju `https://nazwa.netlify.app`. Zapisz go — będzie potrzebny w kroku 3.
5. Otwórz adres w Safari → Udostępnij → Dodaj do ekranu początkowego.

Jeśli Netlify na iPhonie nie pozwala wybrać całego folderu, użyj iPada w orientacji poziomej albo opublikuj folder przez panel Netlify z komputera znajomej osoby. Nie otwieraj `index.html` bezpośrednio z Plików — PWA wymaga HTTPS.

## Krok 2 — utwórz klucz OpenAI API
1. Otwórz https://platform.openai.com/api-keys i zaloguj się.
2. Utwórz nowy klucz API.
3. Skopiuj go i przechowuj prywatnie. Nie wklejaj go do aplikacji ani czatu.
4. Sprawdź rozliczanie API: https://platform.openai.com/settings/organization/billing. Ustaw limit budżetu/alert, jeśli jest dostępny.

## Krok 3 — opublikuj agenta na Cloudflare Workers
1. Otwórz https://dash.cloudflare.com/ i zaloguj się (utwórz darmowe konto, jeśli go nie masz).
2. Wejdź w **Workers & Pages** → **Create** → **Create Worker**.
3. Nadaj nazwę np. `przepisnik-ai` i utwórz Worker.
4. Wybierz **Edit code**. Zastąp kod przykładowy całą zawartością pliku `worker.js` z tego ZIP-a. Zapisz i kliknij **Deploy**.
5. W ustawieniach Workera otwórz **Settings → Variables and Secrets**.
6. Dodaj dwa **Secrets**:
   - `OPENAI_API_KEY` — Twój klucz API OpenAI.
   - `APP_ACCESS_TOKEN` — własne, losowe hasło dostępu do prywatnego endpointu (co najmniej 32 znaki). Wygeneruj własne losowe hasło (co najmniej 32 znaki); nie używaj wartości zapisanej w żadnym publicznym repozytorium:


7. Dodaj zwykłe zmienne (Variables):
   - `OPENAI_MODEL` = `gpt-4.1-mini`
   - `ALLOWED_ORIGIN` = dokładny adres Netlify z kroku 1, bez końcowego ukośnika, np. `https://nazwa.netlify.app`
8. Zapisz zmiany i ponownie wdroż Worker.
9. Adres endpointu będzie wyglądał tak: `https://NAZWA-WORKERA.NAZWA-KONTA.workers.dev/api/recipe-parse`.

## Krok 4 — połącz aplikację z agentem
1. Otwórz opublikowaną aplikację Przepiśnik AI na iPhonie.
2. Wejdź w **Więcej → Ustawienia → Agent AI**.
3. W polu **Adres endpointu agenta** wpisz pełny adres zakończony `/api/recipe-parse`.
4. W polu **Hasło dostępu do agenta** wpisz dokładnie tę samą wartość, którą ustawiłeś jako sekret `APP_ACCESS_TOKEN` w Cloudflare.
5. Kliknij **Zapisz ustawienia**.

## Krok 5 — test
1. Wejdź w Dodaj przepis.
2. Wklej opis przepisu ze składnikami i krokami albo dodaj 2–3 zrzuty ekranu z rolki.
3. Kliknij **Agent AI – utwórz cały przepis**.
4. Sprawdź nazwę, opis, składniki, gramatury, porcje, kategorię i kroki. Następnie kliknij **Zapisz przepis**.

## Co agent potrafi / czego nie potrafi
- Potrafi analizować tekst, kilka obrazów jednocześnie oraz transkrypcję ścieżki dźwiękowej z dostarczonego pliku.
- Potrafi zaproponować nazwę, opis, składniki, ilości, kroki, czas, porcje, kategorię, podkategorię i tagi.
- Nie pobiera automatycznie filmu z samego linku Instagram. Instagram może wymagać logowania i ogranicza automatyczny dostęp. Najpewniejszy import: udostępnij/zapisz materiał, a następnie dodaj plik lub zrzuty ekranu.
- Nie zapisuje przepisu automatycznie bez Twojej kontroli — wypełnia formularz, a Ty zatwierdzasz kartę.

## Prywatność i koszty
- Przepisy i zdjęcia okładkowe zapisują się lokalnie na danym urządzeniu.
- Materiały wysłane do analizy są przesyłane przez Cloudflare Worker do OpenAI API.
- Korzystanie z OpenAI API jest płatne oddzielnie od subskrypcji ChatGPT. Koszt zależy od długości audio, liczby i rozmiaru zdjęć oraz modelu.
- Hasło `APP_ACCESS_TOKEN` jest prostą dodatkową blokadą, nie pełnym systemem logowania. Ogranicz dostęp do adresu aplikacji i ustaw limity wydatków API.
- Eksportuj regularnie kopię JSON w Ustawieniach. Dane na iPhonie i iPadzie nie synchronizują się.
