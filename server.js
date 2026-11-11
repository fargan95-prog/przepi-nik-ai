import { createServer } from "node:http";

const PORT = Number(process.env.PORT || 10000);
const schema = {
  type: "object", additionalProperties: false,
  properties: {
    isRecipe:{type:"boolean"}, name:{type:"string"}, description:{type:"string"},
    category:{type:"string"}, subcategory:{type:"string"}, servings:{type:"integer"},
    time:{type:"integer"},
    ingredients:{type:"array",items:{type:"object",additionalProperties:false,properties:{
      name:{type:"string"},amount:{type:"string"},unit:{type:"string"}
    },required:["name","amount","unit"]}},
    steps:{type:"array",items:{type:"string"}},tags:{type:"array",items:{type:"string"}},
    needsReview:{type:"boolean"},sourceNote:{type:"string"}
  },
  required:["isRecipe","name","description","category","subcategory","servings","time","ingredients","steps","tags","needsReview","sourceNote"]
};
const instructions = `Jesteś agentem AI organizującym prywatną książkę kucharską po polsku.
Wyodrębnij przepis z tekstu i zdjęć. Analizuj wszystkie zdjęcia łącznie.
Nie wymyślaj składników, gramatur, czasu ani porcji. Brak ilości oznacz jako "nie podano", ustaw needsReview=true i wyjaśnij w sourceNote.
Nie dopisuj kroków nieuzasadnionych materiałem. Każdy krok zapisz osobno.
Sam link do Instagrama nie oznacza dostępu do rolki. Jeśli materiał nie zawiera przepisu, ustaw isRecipe=false.
Zachowaj polskie jednostki. Użyj kategorii użytkownika; maksymalnie 6 trafnych tagów.
Niepewności i braki opisz konkretnie w sourceNote.`;
function send(res,status,data,origin="*"){
  res.writeHead(status,{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store","Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"Content-Type, X-App-Token","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin"});
  res.end(JSON.stringify(data));
}
const server=createServer(async(req,res)=>{
  const origin=req.headers.origin||"*", allowed=process.env.ALLOWED_ORIGIN||"*";
  const corsOrigin=allowed==="*"||origin===allowed? (allowed==="*"?"*":allowed):"null";
  if(req.method==="OPTIONS"){res.writeHead(204,{"Access-Control-Allow-Origin":corsOrigin,"Access-Control-Allow-Headers":"Content-Type, X-App-Token","Access-Control-Allow-Methods":"POST, OPTIONS"});return res.end();}
  const url=new URL(req.url,"http://localhost");
  if(url.pathname==="/health"&&req.method==="GET")return send(res,200,{ok:true,service:"Przepiśnik AI"});
  if(url.pathname!=="/api/recipe-parse"||req.method!=="POST")return send(res,404,{error:"Nie znaleziono endpointu."},corsOrigin);
  if(corsOrigin==="null")return send(res,403,{error:"Niedozwolone źródło żądania."},corsOrigin);
  if(!process.env.OPENAI_API_KEY)return send(res,500,{error:"Brak OPENAI_API_KEY w sekretach backendu."},corsOrigin);
  try{
    let raw="";for await(const chunk of req){raw+=chunk;if(raw.length>34_000_000)return send(res,413,{error:"Materiał jest zbyt duży. Zmniejsz zdjęcia."},corsOrigin);}
    const body=JSON.parse(raw||"{}");
    const text=String(body.text||"").slice(0,50000), sourceUrl=String(body.url||"").slice(0,2000);
    const categories=Array.isArray(body.categories)?body.categories.slice(0,40).map(x=>String(x).slice(0,80)):["Śniadania","Obiady","Kolacje","Zupy","Desery","Przekąski","Sosy i dodatki","Napoje"];
    const imgs=Array.isArray(body.imageDataList)?body.imageDataList.filter(x=>typeof x==="string"&&x.startsWith("data:image/")).slice(0,8):[];
    if(!imgs.length&&typeof body.imageData==="string"&&body.imageData.startsWith("data:image/"))imgs.push(body.imageData);
    const content=[{type:"input_text",text:`Kategorie: ${categories.join(", ")}\nLink źródłowy (nie oznacza pobrania treści): ${sourceUrl||"brak"}\nMateriał tekstowy:\n${text||"brak"}\nUtwórz kartę przepisu zgodnie z zasadami.`}];
    for(const data of imgs)content.push({type:"input_image",image_url:data,detail:"high"});
    if(body.videoData&&typeof body.videoData==="string"){
      const m=body.videoData.match(/^data:([^;,]+);base64,([\\s\\S]+)$/);
      if(!m)return send(res,400,{error:"Nieprawidłowy plik audio/wideo."},corsOrigin);
      const ext=({"video/mp4":"mp4","video/webm":"webm","audio/mp4":"m4a","audio/m4a":"m4a","audio/mpeg":"mp3","audio/wav":"wav"})[m[1]];
      if(!ext)return send(res,415,{error:"Nieobsługiwany format audio/wideo."},corsOrigin);
      const bytes=Buffer.from(m[2],"base64");if(bytes.length>25*1024*1024)return send(res,413,{error:"Plik audio/wideo przekracza 25 MB."},corsOrigin);
      const form=new FormData();form.append("file",new Blob([bytes],{type:m[1]}),`material.${ext}`);form.append("model","whisper-1");form.append("language","pl");
      const tr=await fetch("https://api.openai.com/v1/audio/transcriptions",{method:"POST",headers:{Authorization:`Bearer ${process.env.OPENAI_API_KEY}`},body:form});
      const td=await tr.json().catch(()=>({}));if(!tr.ok)return send(res,502,{error:td.error?.message||"Błąd transkrypcji audio."},corsOrigin);
      content[0].text+=`\nTranskrypcja dostarczonego pliku:\n${td.text||""}`;
    }
    if(!text&&!imgs.length&&!body.videoData)return send(res,200,{isRecipe:false,name:"",description:"",category:"",subcategory:"",servings:0,time:0,ingredients:[],steps:[],tags:[],needsReview:true,sourceNote:"Dodaj tekst, zdjęcia lub plik audio/wideo."},corsOrigin);
    const api=await fetch("https://api.openai.com/v1/responses",{method:"POST",headers:{Authorization:`Bearer ${process.env.OPENAI_API_KEY}`,"Content-Type":"application/json"},body:JSON.stringify({
      model:process.env.OPENAI_MODEL||"gpt-4.1-mini",
      input:[{role:"system",content:[{type:"input_text",text:instructions}]},{role:"user",content}],
      text:{format:{type:"json_schema",name:"recipe_card",strict:true,schema}},max_output_tokens:3500
    })});
    const payload=await api.json().catch(()=>({}));if(!api.ok)return send(res,502,{error:payload.error?.message||"Błąd usługi AI."},corsOrigin);
    const output=payload.output?.flatMap(x=>x.content||[]).find(x=>x.type==="output_text")?.text||payload.output_text;
    if(!output)return send(res,502,{error:"Agent nie zwrócił danych przepisu."},corsOrigin);
    const recipe=JSON.parse(output);recipe.sourceUrl=sourceUrl;return send(res,200,recipe,corsOrigin);
  }catch(e){return send(res,500,{error:e.message||"Nieoczekiwany błąd backendu."},corsOrigin);}
});
server.listen(PORT,"0.0.0.0",()=>console.log(`Przepiśnik AI backend listening on ${PORT}`));
