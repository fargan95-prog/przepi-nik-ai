/**
 * Przepiśnik AI — Cloudflare Worker backend
 * Deploy as a Worker. Set OPENAI_API_KEY as a Secret.
 * Optional variables: OPENAI_MODEL (default gpt-4.1-mini), ALLOWED_ORIGIN.
 * Never put OPENAI_API_KEY in the PWA frontend.
 */
const schema = {
  type: "object",
  additionalProperties: false,
  properties: {
    isRecipe: { type: "boolean" },
    name: { type: "string" },
    description: { type: "string" },
    category: { type: "string" },
    subcategory: { type: "string" },
    servings: { type: "integer" },
    time: { type: "integer" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          name: { type: "string" },
          amount: { type: "string" },
          unit: { type: "string" }
        },
        required: ["name", "amount", "unit"]
      }
    },
    steps: { type: "array", items: { type: "string" } },
    tags: { type: "array", items: { type: "string" } },
    needsReview: { type: "boolean" },
    sourceNote: { type: "string" }
  },
  required: ["isRecipe", "name", "description", "category", "subcategory", "servings", "time", "ingredients", "steps", "tags", "needsReview", "sourceNote"]
};

const instructions = `Jesteś agentem AI organizującym prywatną książkę kucharską po polsku.
Twoje zadanie: z dostarczonego tekstu, obrazów i/lub transkrypcji wyodrębnij kompletny przepis i zwróć go zgodnie ze schematem JSON. Analizuj wszystkie dostarczone zrzuty ekranu łącznie; często składniki i kroki są rozdzielone między kilka kadrów.
ZASADY KRYTYCZNE:
- Nie wymyślaj składników, gramatur, czasu ani liczby porcji. Jeśli ilości nie ma w źródle, wpisz amount="nie podano", unit="" i ustaw needsReview=true.
- Nie dopisuj kroków, których źródło nie uzasadnia. Możesz uporządkować język i kolejność tylko wtedy, gdy wynika to z materiału. Każdy krok przygotowania zapisz osobno, w logicznej kolejności.
- Jeśli źródło zawiera jedynie zdjęcie gotowego dania albo sam link bez dostępnej treści, nie udawaj, że znasz przepis. Ustaw isRecipe=false, a sourceNote wyjaśnij, czego brakuje.
- Link Instagram jest metadanymi źródła. Nie twierdź, że obejrzałeś rolkę ani pobrałeś jej treść, jeśli nie została dostarczona jako tekst lub obraz.
- Zachowaj polskie jednostki (g, kg, ml, l, szt., łyżka, łyżeczka). Przeliczaj tylko oczywiste jednostki, bez zgadywania.
- Nazwa ma być krótka i czytelna; opis krótki, rzeczowy.
- Wybierz kategorię najlepiej pasującą do listy kategorii użytkownika. Jeśli żadna nie pasuje, zaproponuj nową kategorię.
- Subkategoria ma być krótka. Tagi maksymalnie 6, np. fit, wegetariańskie, wysokobiałkowe, szybkie.
- Jeśli jakiekolwiek dane są niepełne lub niejednoznaczne, ustaw needsReview=true i opisz to w sourceNote. W sourceNote wskaż konkretnie, których danych brakuje (np. gramatury, temperatury, czas pieczenia).
- Jeśli to nie jest przepis, zwróć isRecipe=false, puste tablice, servings=0, time=0 i wyjaśnij w sourceNote.`;

function corsHeaders(origin, allowed) {
  const ok = !allowed || allowed === "*" || origin === allowed;
  return {
    "Access-Control-Allow-Origin": ok ? (allowed && allowed !== "*" ? allowed : "*") : "null",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Token",
    "Vary": "Origin"
  };
}
function json(data, status, cors) {
  return new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const cors = corsHeaders(origin, env.ALLOWED_ORIGIN || "*");
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    const url = new URL(request.url);
    if (url.pathname !== "/api/recipe-parse" || request.method !== "POST") return json({ error: "Not found" }, 404, cors);
    if (cors["Access-Control-Allow-Origin"] === "null") return json({ error: "Origin not allowed" }, 403, cors);
    if (!env.OPENAI_API_KEY) return json({ error: "Brak sekretu OPENAI_API_KEY w konfiguracji Worker." }, 500, cors);
    if (!env.APP_ACCESS_TOKEN) return json({ error: "Brak sekretu APP_ACCESS_TOKEN w konfiguracji Worker." }, 500, cors);
    if (request.headers.get("X-App-Token") !== env.APP_ACCESS_TOKEN) return json({ error: "Nieprawidłowe hasło dostępu do agenta." }, 401, cors);

    let body;
    try {
      const raw = await request.text();
      if (raw.length > 34_000_000) return json({ error: "Materiał jest zbyt duży. Zmniejsz zdjęcie i spróbuj ponownie." }, 413, cors);
      body = JSON.parse(raw);
    } catch { return json({ error: "Nieprawidłowe dane JSON." }, 400, cors); }

    const text = String(body.text || "").slice(0, 50000);
    const sourceUrl = String(body.url || "").slice(0, 2000);
    const categories = Array.isArray(body.categories) ? body.categories.slice(0, 40).map(x => String(x).slice(0, 80)) : ["Śniadania", "Obiady", "Kolacje", "Zupy", "Desery", "Przekąski", "Sosy i dodatki", "Napoje"];
    const imageList = Array.isArray(body.imageDataList) ? body.imageDataList.filter(x => typeof x === "string" && x.startsWith("data:image/")).slice(0, 8) : [];
    const legacyImage = typeof body.imageData === "string" && body.imageData.startsWith("data:image/") ? body.imageData : null;
    const imageDataList = imageList.length ? imageList : (legacyImage ? [legacyImage] : []);
    const videoData = typeof body.videoData === "string" && body.videoData.startsWith("data:") ? body.videoData : null;
    if (!text && !imageDataList.length && !videoData) {
      return json({ isRecipe: false, name: "", description: "", category: "", subcategory: "", servings: 0, time: 0, ingredients: [], steps: [], tags: [], needsReview: true, sourceNote: sourceUrl ? "Instagram nie udostępnił treści rolki na podstawie samego linku. Wklej opis posta lub dodaj zrzuty ekranu z przepisu." : "Dodaj tekst lub zdjęcie przepisu." }, 200, cors);
    }

    const content = [{ type: "input_text", text: `Kategorie użytkownika: ${categories.join(", ")}\nLink źródłowy (nie oznacza, że treść linku została pobrana): ${sourceUrl || "brak"}\n\nMateriał tekstowy:\n${text || "brak"}\n\nPrzeanalizuj materiał i utwórz kartę przepisu. Nie uzupełniaj brakujących danych domysłami.` }];
    for (const imageData of imageDataList) content.push({ type: "input_image", image_url: imageData, detail: "high" });

    // For a user-supplied MP4/WebM/M4A/MP3 file, transcribe the audio first.
    // This does not download or scrape Instagram content from a URL.
    if (videoData) {
      try {
        const match = videoData.match(/^data:([^;,]+);base64,([\s\S]+)$/);
        if (!match) return json({ error: "Nieprawidłowy plik audio/wideo." }, 400, cors);
        const mime = match[1];
        const ext = ({ "video/mp4": "mp4", "video/webm": "webm", "audio/mp4": "m4a", "audio/m4a": "m4a", "audio/mpeg": "mp3", "audio/wav": "wav" })[mime];
        if (!ext) return json({ error: "Format pliku nie jest obsługiwany. Użyj MP4, WebM, M4A, MP3 lub WAV." }, 415, cors);
        const bytes = Uint8Array.from(atob(match[2]), c => c.charCodeAt(0));
        if (bytes.byteLength > 25 * 1024 * 1024) return json({ error: "Plik audio przekracza limit 25 MB." }, 413, cors);
        const form = new FormData();
        form.append("file", new Blob([bytes], { type: mime }), `instagram-reel.${ext}`);
        form.append("model", "gpt-transcribe");
        form.append("languages[]", "pl");
        form.append("prompt", "Polski przepis kulinarny. Zachowaj nazwy składników, ilości, gramatury, temperatury, czasy i nazwy produktów. Nie pomijaj liczb.");
        const tr = await fetch("https://api.openai.com/v1/audio/transcriptions", { method: "POST", headers: { "Authorization": `Bearer ${env.OPENAI_API_KEY}` }, body: form });
        const trData = await tr.json().catch(() => ({}));
        if (!tr.ok) return json({ error: trData.error?.message || "Nie udało się przepisać ścieżki dźwiękowej." }, 502, cors);
        const transcript = String(trData.text || "").trim();
        if (transcript) content[0].text += `\n\nTranskrypcja wypowiedzi z dostarczonego pliku audio/wideo:\n${transcript}`;
      } catch (e) { return json({ error: "Błąd odczytu pliku audio/wideo: " + e.message }, 502, cors); }
    }

    let apiResponse;
    try {
      apiResponse = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: { "Authorization": `Bearer ${env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: env.OPENAI_MODEL || "gpt-4.1-mini",
          input: [
            { role: "system", content: [{ type: "input_text", text: instructions }] },
            { role: "user", content }
          ],
          text: { format: { type: "json_schema", name: "recipe_card", strict: true, schema } },
          max_output_tokens: 3500
        })
      });
    } catch { return json({ error: "Nie udało się połączyć z usługą AI." }, 502, cors); }

    const payload = await apiResponse.json().catch(() => ({}));
    if (!apiResponse.ok) return json({ error: payload.error?.message || "Błąd usługi AI." }, 502, cors);
    const output = payload.output?.flatMap(item => item.content || []).find(item => item.type === "output_text")?.text || payload.output_text;
    if (!output) return json({ error: "Agent nie zwrócił danych przepisu." }, 502, cors);
    try {
      const recipe = JSON.parse(output);
      recipe.sourceUrl = sourceUrl;
      return json(recipe, 200, cors);
    } catch { return json({ error: "Agent zwrócił nieprawidłowy format przepisu." }, 502, cors); }
  }
};
