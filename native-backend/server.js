import express from "express";
import helmet from "helmet";
import cors from "cors";
import multer from "multer";
import rateLimit from "express-rate-limit";
import OpenAI from "openai";

const app = express();
app.disable("x-powered-by");
app.use(helmet({ crossOriginResourcePolicy: { policy: "cross-origin" } }));
app.use(cors({ origin: process.env.ALLOWED_ORIGIN ? process.env.ALLOWED_ORIGIN.split(",") : false }));
app.use(express.json({ limit: "1mb" }));
app.use(rateLimit({ windowMs: 60_000, limit: 20, standardHeaders: true, legacyHeaders: false }));
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 24 * 1024 * 1024, files: 9, fields: 8 },
  fileFilter: (_req, file, cb) => {
    const ok = /^(image\/(jpeg|png|webp|heic)|audio\/(mpeg|mp4|wav|x-wav|m4a|aac|webm)|video\/(mp4|quicktime|webm))$/i.test(file.mimetype);
    cb(ok ? null : new Error("Nieobsługiwany format pliku."), ok);
  }
});
const client = () => {
  if (!process.env.OPENAI_API_KEY) throw new Error("Backend nie ma skonfigurowanego klucza AI.");
  return new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
};
const recipeSchema = {
  type: "object", additionalProperties: false,
  properties: {
    isRecipe: { type: "boolean" }, name: { type: "string" }, description: { type: "string" },
    category: { type: "string" }, subcategory: { type: "string" }, servings: { type: ["integer","null"] },
    prepMinutes: { type: ["integer","null"] }, cookMinutes: { type: ["integer","null"] },
    ingredients: { type: "array", items: { type: "object", additionalProperties: false, properties: {
      name: { type: "string" }, amount: { type: ["string","null"] }, unit: { type: ["string","null"] }, note: { type: "string" }
    }, required: ["name","amount","unit","note"] } },
    steps: { type: "array", items: { type: "string" } }, tags: { type: "array", items: { type: "string" } },
    needsReview: { type: "boolean" }, uncertainties: { type: "array", items: { type: "string" } }
  },
  required: ["isRecipe","name","description","category","subcategory","servings","prepMinutes","cookMinutes","ingredients","steps","tags","needsReview","uncertainties"]
};
const instructions = `Jesteś agentem prywatnej książki kucharskiej po polsku. Na podstawie przekazanego tekstu, zdjęć i transkrypcji przygotuj wierną kartę przepisu.
Nie dopowiadaj brakujących składników, ilości, czasu, temperatur ani kroków. Brak oznacz null lub dodaj do uncertainties i ustaw needsReview=true. Jeśli źródło jest wyłącznie linkiem do Instagrama i nie zawiera treści przepisu, nie udawaj, że widzisz rolkę: isRecipe=false i wyjaśnij, że potrzebny jest plik, zrzut ekranu albo tekst. Zachowaj jednostki źródłowe. Nazwa i opis mają być zwięzłe. Kategorie po polsku.`;
app.get("/health", (_req, res) => res.json({ ok: true, service: "Przepiśnik AI native backend" }));
app.post("/v1/recipes/import", upload.array("files", 9), async (req, res) => {
  try {
    const ai = client();
    const text = String(req.body.text || "").slice(0, 20_000);
    const sourceURL = String(req.body.sourceURL || "").slice(0, 2_000);
    const content = [{ type: "input_text", text: [text && "Tekst materiału:\n"+text, sourceURL && "Adres źródła (sam link nie daje dostępu do prywatnej treści): "+sourceURL].filter(Boolean).join("\n\n") || "Przeanalizuj załączone materiały." }];
    for (const file of req.files || []) {
      if (file.mimetype.startsWith("image/")) {
        const data = file.buffer.toString("base64");
        content.push({ type: "input_image", image_url: "data:"+file.mimetype+";base64,"+data, detail: "high" });
      } else if (file.mimetype.startsWith("audio/") || file.mimetype.startsWith("video/")) {
        try {
          const transcript = await ai.audio.transcriptions.create({
            file: new File([file.buffer], file.originalname || "shared-media.mp4", { type: file.mimetype }),
            model: "gpt-4o-mini-transcribe",
            language: "pl"
          });
          content.push({ type: "input_text", text: "Transkrypcja udostępnionego materiału "+file.originalname+":\n"+transcript.text });
        } catch (e) {
          content.push({ type: "input_text", text: "Nie udało się automatycznie odczytać audio/wideo "+file.originalname+". Nie wyciągaj z tego pliku niepotwierdzonych wniosków." });
        }
      }
    }
    const response = await ai.responses.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      instructions,
      input: [{ role: "user", content }],
      text: { format: { type: "json_schema", name: "recipe_import", strict: true, schema: recipeSchema } },
      max_output_tokens: 3500
    });
    const recipe = JSON.parse(response.output_text);
    res.json({ ok: true, recipe, sourceURL });
  } catch (error) {
    const status = error.status && error.status >= 400 && error.status < 600 ? error.status : 500;
    res.status(status).json({ ok: false, error: status === 401 ? "Błąd autoryzacji usługi AI." : (error.message || "Nie udało się przeanalizować materiału.") });
  }
});
app.use((error, _req, res, _next) => res.status(400).json({ ok: false, error: error.message || "Nieprawidłowy materiał." }));
const port = Number(process.env.PORT || 10000);
app.listen(port, "0.0.0.0", () => console.log("Native backend listening on "+port));
