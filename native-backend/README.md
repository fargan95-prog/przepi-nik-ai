# Przepiśnik AI — backend natywny

Backend odbiera materiały z natywnej aplikacji iOS, transkrybuje udostępnione audio/wideo, analizuje obrazy i zwraca strukturę przepisu.

## Konfiguracja środowiska
- `OPENAI_API_KEY` — sekret ustawiany wyłącznie w panelu hostingu
- `OPENAI_MODEL` — opcjonalnie, domyślnie `gpt-4o-mini`
- `ALLOWED_ORIGIN` — opcjonalna lista originów dla klientów webowych; natywny iOS nie używa przeglądarkowego CORS

## Uruchomienie
Node.js 20+: `npm install`, następnie `npm start`.

## API
- `GET /health`
- `POST /v1/recipes/import` jako multipart/form-data:
  - `text` — tekst, podpis lub transkrypcja
  - `sourceURL` — oryginalny link
  - `files` — maksymalnie 9 plików do 24 MB każdy

Klucz AI pozostaje po stronie serwera. Endpoint ma limit żądań, limit wielkości plików i walidację MIME. Produkcyjnie należy dodać uwierzytelnianie użytkownika, limity kosztowe i trwałe przechowywanie przepisów.

Instagram może udostępnić jedynie URL, a nie oryginalne media. Backend nie omija prywatności ani ograniczeń dostępu Instagrama; w takim przypadku poprosi o zrzuty ekranu lub plik zapisany przez użytkownika.
