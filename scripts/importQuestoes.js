require("dotenv").config();
const fs = require("node:fs/promises");
const path = require("node:path");
const { getSupabaseAdmin, isSupabaseConfigured } = require("../services/supabaseClient");
const { validateQuestion, parseQuestionDocument, parseQuestionCsv } = require("../services/questionImportService");

async function nextCode(db) {
  const { data, error } = await db.from("questoes").select("codigo").like("codigo", "Q#%").limit(10000);
  if (error) throw error;
  const max = (data || []).reduce((value, row) => {
    const match = /^Q#(\d+)$/.exec(row.codigo || "");
    return match ? Math.max(value, Number(match[1])) : value;
  }, 0);
  return `Q#${String(max + 1).padStart(5, "0")}`;
}

async function importQuestions() {
  if (!isSupabaseConfigured()) throw new Error("Configure as credenciais server-side do Supabase.");
  const inputPath = process.argv[2];
  if (!inputPath) throw new Error("Uso: npm run import:questoes -- caminho/para/questoes.json|csv");
  const absolutePath = path.resolve(inputPath);
  const contents = await fs.readFile(absolutePath, "utf8");
  const questions = absolutePath.toLowerCase().endsWith(".csv") ? parseQuestionCsv(contents) : parseQuestionDocument(JSON.parse(contents));
  if (questions.length > 500) throw new Error("Importe no máximo 500 questões por execução.");
  const db = getSupabaseAdmin();
  const result = { importadas: 0, duplicadas: 0, erros: [] };
  for (const [index, raw] of questions.entries()) {
    const { question, errors } = validateQuestion(raw);
    if (errors.length) { result.erros.push({ linha: index + 1, erros: errors }); continue; }
    question.codigo ||= await nextCode(db);
    const { data: existing, error: lookupError } = await db.from("questoes").select("id").eq("codigo", question.codigo).maybeSingle();
    if (lookupError) throw lookupError;
    if (existing) { result.duplicadas += 1; continue; }
    const { alternativas, ...row } = question;
    Object.assign(row, { ativa: true, anulada: false, origem: "manual", gerada_por_ia: false });
    const { data: inserted, error } = await db.from("questoes").insert(row).select("id").single();
    if (error) { result.erros.push({ linha: index + 1, erros: ["Falha ao gravar a questão."] }); continue; }
    const { error: alternativeError } = await db.from("questao_alternativas").insert(alternativas.map((item) => ({ ...item, questao_id: inserted.id })));
    if (alternativeError) {
      await db.from("questoes").delete().eq("id", inserted.id);
      result.erros.push({ linha: index + 1, erros: ["Falha ao gravar as alternativas."] });
      continue;
    }
    result.importadas += 1;
  }
  console.log(JSON.stringify(result, null, 2));
}

importQuestions().catch((error) => {
  console.error("Importação interrompida:", error.message);
  process.exitCode = 1;
});
