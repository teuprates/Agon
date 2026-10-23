const express = require("express");
const questionRepository = require("../repositories/questoes");
const { getSupabaseAdmin, isSupabaseConfigured } = require("../services/supabaseClient");
const { requireRole } = require("../middleware/auth");

const DIFFICULTIES = new Set(["facil", "media", "dificil"]);
const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/;

function parseInteger(value, fallback, min, max) {
  if (value === undefined || value === "") return fallback;
  if (!/^\d+$/.test(String(value))) return null;
  const number = Number(value);
  return number >= min && number <= max ? number : null;
}

function createQuestionRouter() {
  const router = express.Router();

  router.get("/filtros", async (_req, res) => {
    try { return res.json(await questionRepository.listFilters()); }
    catch (error) { return res.status(error.status || 503).json({ erro: error.message || "Não foi possível carregar os filtros." }); }
  });

  router.get("/", async (req, res) => {
    const { disciplina, assunto, banca, ano, dificuldade, busca } = req.query;
    const pagina = parseInteger(req.query.pagina, 1, 1, 100000);
    const porPagina = parseInteger(req.query.porPagina, 10, 1, 50);
    if (pagina === null || porPagina === null) return res.status(400).json({ erro: "Paginação inválida." });
    if (ano && parseInteger(ano, 0, 1900, new Date().getFullYear() + 1) === null) return res.status(400).json({ erro: "Ano inválido." });
    if (dificuldade && !DIFFICULTIES.has(dificuldade)) return res.status(400).json({ erro: "Dificuldade inválida." });
    for (const [name, value, max] of [["disciplina", disciplina, 80], ["assunto", assunto, 120], ["banca", banca, 40], ["busca", busca, 200]]) {
      if (value !== undefined && (typeof value !== "string" || value.length > max)) return res.status(400).json({ erro: `Filtro ${name} inválido.` });
    }
    try { return res.json(await questionRepository.listQuestions({ disciplina, assunto, banca, ano, dificuldade, busca, pagina, porPagina }, req.session.user.id)); }
    catch (error) { return res.status(error.status || 503).json({ erro: error.message || "Não foi possível carregar as questões." }); }
  });

  router.post("/:id/responder", async (req, res) => {
    if (!UUID_RE.test(req.params.id)) return res.status(400).json({ erro: "Identificador de questão inválido." });
    const { resposta, tempoGastoSegundos = 0 } = req.body || {};
    if (typeof resposta !== "string" || !/^(A|B|C|D|E)$/.test(resposta)) return res.status(400).json({ erro: "Informe uma alternativa válida." });
    if (!Number.isInteger(tempoGastoSegundos) || tempoGastoSegundos < 0 || tempoGastoSegundos > 7200) return res.status(400).json({ erro: "O tempo deve ser um número inteiro entre 0 e 7200 segundos." });
    try {
      const result = await questionRepository.answerQuestion(req.session.user.id, req.params.id, resposta, tempoGastoSegundos);
      if (!result || result.erro === "QUESTAO_INDISPONIVEL") return res.status(404).json({ erro: "Questão não encontrada ou indisponível." });
      if (result.erro === "RESPOSTA_INVALIDA") return res.status(400).json({ erro: "A resposta não é válida para esta questão." });
      return res.json({ acertou: result.acertou, gabarito: result.gabarito, comentario_professor: result.comentario_professor, justificativas: result.justificativas || [], xpGanho: result.xp_ganho || 0 });
    } catch (error) { return res.status(error.status || 503).json({ erro: error.message || "Não foi possível registrar sua resposta." }); }
  });

  router.post("/:id/favoritar", async (req, res) => {
    if (!UUID_RE.test(req.params.id)) return res.status(400).json({ erro: "Identificador de questão inválido." });
    try { await questionRepository.favoriteQuestion(req.session.user.id, req.params.id); return res.json({ sucesso: true }); }
    catch (error) { return res.status(error.status || 503).json({ erro: error.message || "Não foi possível favoritar a questão." }); }
  });

  router.post("/responder", (req, res) => res.status(410).json({ erro: "Endpoint antigo desativado. Use /api/questoes/:id/responder." }));

  router.post("/gerar-ia", requireRole("professor", "admin"), async (req, res) => {
    if (!isSupabaseConfigured()) return res.status(503).json({ erro: "Banco de dados indisponível." });
    const { disciplina, assunto = "Geral", banca = "Agon", dificuldade = "media" } = req.body || {};
    if (typeof disciplina !== "string" || !disciplina.trim() || disciplina.length > 80 || typeof assunto !== "string" || assunto.length > 120 || !DIFFICULTIES.has(dificuldade) || typeof banca !== "string" || banca.length > 40) {
      return res.status(400).json({ erro: "Informe disciplina, assunto, banca e dificuldade válidos." });
    }
    return res.status(501).json({ erro: "Geração de questões por IA aguardará a aprovação da política de revisão humana." });
  });

  router.post("/:id/explicar", async (req, res) => {
    if (!UUID_RE.test(req.params.id)) return res.status(400).json({ erro: "Identificador de questão inválido." });
    const userId = req.session.user.id;
    const respostaSelecionada = req.body?.respostaSelecionada;
    if (typeof respostaSelecionada !== "string" || !/^(A|B|C|D|E)$/.test(respostaSelecionada)) return res.status(400).json({ erro: "Informe a alternativa selecionada." });
    if (!isSupabaseConfigured()) return res.status(503).json({ erro: "Banco de questões indisponível." });
    try {
      const question = await questionRepository.getQuestion(req.params.id, { includeAnswer: true });
      if (!question) return res.status(404).json({ erro: "Questão não encontrada ou indisponível." });
      const { data: attempt, error } = await getSupabaseAdmin().from("question_attempts")
        .select("resposta_selecionada").eq("user_id", userId).eq("questao_uuid", question.id).eq("resposta_selecionada", respostaSelecionada).limit(1).maybeSingle();
      if (error) throw error;
      if (!attempt) return res.status(403).json({ erro: "Responda à questão antes de pedir a explicação completa." });
      const context = {
        enunciado: question.enunciado,
        alternativas: question.questao_alternativas || [],
        respostaSelecionada: attempt.resposta_selecionada,
        gabarito: question.gabarito_oficial,
        comentarioProfessor: question.comentario_professor,
      };
      const zukaService = require("../services/zukaService");
      const result = await zukaService.processUserMessage({ userId, messageText: "Explique esta questão e o raciocínio da alternativa correta.", questionContext: context });
      return res.json(result);
    } catch (error) { return res.status(error.status || 500).json({ erro: error.message || "Não foi possível gerar a explicação." }); }
  });

  return router;
}

module.exports = createQuestionRouter;
