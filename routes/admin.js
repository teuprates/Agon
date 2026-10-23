const express = require("express");
const path = require("node:path");
const { getSupabaseAdmin, isSupabaseConfigured } = require("../services/supabaseClient");
const { validateQuestion, parseQuestionDocument, parseQuestionCsv } = require("../services/questionImportService");

function createAdminRouter() {
  const router = express.Router();

  router.get("/questoes/modelo", (_req, res) => {
    const format = _req.query.formato === "csv" ? "csv" : "json";
    res.download(path.join(__dirname, "..", "data", "questoes", `modelo.${format}`), `modelo-questoes.${format}`);
  });

  async function nextCode(db) {
    const { data, error } = await db.from("questoes").select("codigo").like("codigo", "Q#%").limit(10000);
    if (error) throw error;
    const highest = (data || []).reduce((max, row) => {
      const match = /^Q#(\d+)$/.exec(row.codigo || "");
      return match ? Math.max(max, Number(match[1])) : max;
    }, 0);
    return `Q#${String(highest + 1).padStart(5, "0")}`;
  }

  async function saveOne(db, raw, userId, origin = "manual", active = true) {
    const { question, errors } = validateQuestion(raw);
    if (errors.length) return { errors };
    question.codigo ||= await nextCode(db);
    const { data: existing, error: lookupError } = await db.from("questoes").select("id").eq("codigo", question.codigo).maybeSingle();
    if (lookupError) throw lookupError;
    if (existing) return { duplicate: true, codigo: question.codigo };
    const { alternativas, ...row } = question;
    row.ativa = active;
    row.anulada = false;
    row.origem = origin;
    row.gerada_por_ia = origin === "ia";
    row.revisada_por = active ? userId : null;
    row.revisada_em = active ? new Date().toISOString() : null;
    const { data: inserted, error } = await db.from("questoes").insert(row).select("id,codigo").single();
    if (error) throw error;
    const alternativeRows = alternativas.map((alternative) => ({ ...alternative, questao_id: inserted.id }));
    const { error: alternativesError } = await db.from("questao_alternativas").insert(alternativeRows);
    if (alternativesError) {
      await db.from("questoes").delete().eq("id", inserted.id);
      throw alternativesError;
    }
    return { id: inserted.id, codigo: inserted.codigo };
  }

  router.get("/questoes", async (_req, res) => {
    if (!isSupabaseConfigured()) return res.status(503).json({ erro: "Banco de dados indisponível." });
    try {
      const { data, error } = await getSupabaseAdmin().from("questoes")
        .select("id,codigo,disciplina_nome,assunto_nome,banca_sigla,ano,enunciado,ativa,anulada,origem,fonte_url,revisada_por,revisada_em,gabarito_oficial,comentario_professor,questao_alternativas(letra,texto,correta,justificativa_alternativa,ordem)")
        .order("criado_em", { ascending: false }).limit(100);
      if (error) throw error;
      return res.json({ questoes: data || [] });
    } catch (error) { return res.status(503).json({ erro: "Não foi possível carregar as questões administrativas." }); }
  });

  router.post("/questoes", async (req, res) => {
    if (!isSupabaseConfigured()) return res.status(503).json({ erro: "Banco de dados indisponível." });
    try {
      const saved = await saveOne(getSupabaseAdmin(), req.body, req.session.user.id, "manual", true);
      if (saved.errors) return res.status(400).json({ erro: "Revise os campos da questão.", erros: saved.errors });
      if (saved.duplicate) return res.status(409).json({ erro: `O código ${saved.codigo} já está cadastrado.` });
      return res.status(201).json(saved);
    } catch (error) { return res.status(503).json({ erro: "Não foi possível salvar a questão." }); }
  });

  router.post("/questoes/importar-json", async (req, res) => {
    if (!isSupabaseConfigured()) return res.status(503).json({ erro: "Banco de dados indisponível." });
    let questions;
    try { questions = parseQuestionDocument(req.body); }
    catch (error) { return res.status(400).json({ erro: error.message }); }
    if (questions.length > 500) return res.status(413).json({ erro: "Importe no máximo 500 questões por vez." });
    const results = { importadas: [], duplicadas: [], erros: [] };
    for (const [index, question] of questions.entries()) {
      try {
        const saved = await saveOne(getSupabaseAdmin(), question, req.session.user.id, "manual", true);
        if (saved.errors) results.erros.push({ linha: index + 1, erros: saved.errors });
        else if (saved.duplicate) results.duplicadas.push({ linha: index + 1, codigo: saved.codigo });
        else results.importadas.push(saved);
      } catch (_error) { results.erros.push({ linha: index + 1, erros: ["Não foi possível salvar esta questão."] }); }
    }
    return res.status(results.erros.length ? 207 : 201).json(results);
  });

  router.post("/questoes/importar-csv", express.text({ type: ["text/csv", "text/plain"], limit: "1mb" }), async (req, res) => {
    if (!isSupabaseConfigured()) return res.status(503).json({ erro: "Banco de dados indisponível." });
    let questions;
    try { questions = parseQuestionCsv(req.body); }
    catch (error) { return res.status(400).json({ erro: error.message }); }
    if (questions.length > 500) return res.status(413).json({ erro: "Importe no máximo 500 questões por vez." });
    const results = { importadas: [], duplicadas: [], erros: [] };
    for (const [index, question] of questions.entries()) {
      try {
        const saved = await saveOne(getSupabaseAdmin(), question, req.session.user.id, "manual", true);
        if (saved.errors) results.erros.push({ linha: index + 2, erros: saved.errors });
        else if (saved.duplicate) results.duplicadas.push({ linha: index + 2, codigo: saved.codigo });
        else results.importadas.push(saved);
      } catch (_error) { results.erros.push({ linha: index + 2, erros: ["Não foi possível salvar esta questão."] }); }
    }
    return res.status(results.erros.length ? 207 : 201).json(results);
  });

  router.patch("/questoes/:id/status", async (req, res) => {
    if (!isSupabaseConfigured()) return res.status(503).json({ erro: "Banco de dados indisponível." });
    const { status } = req.body || {};
    if (!new Set(["ativa", "inativa", "anulada"]).has(status)) return res.status(400).json({ erro: "Status inválido." });
    try {
      const { data, error } = await getSupabaseAdmin().from("questoes").update({
        ativa: status === "ativa", anulada: status === "anulada",
        revisada_por: req.session.user.id, revisada_em: new Date().toISOString(),
      }).eq("id", req.params.id).select("id,ativa,anulada").maybeSingle();
      if (error) throw error;
      if (!data) return res.status(404).json({ erro: "Questão não encontrada." });
      return res.json(data);
    } catch (_error) { return res.status(503).json({ erro: "Não foi possível atualizar a questão." }); }
  });

  return router;
}

module.exports = createAdminRouter;
