const { getSupabaseAdmin, isSupabaseConfigured } = require("../services/supabaseClient");

const PUBLIC_COLUMNS = "id,codigo,enunciado,texto_associado,disciplina_slug,disciplina_nome,assunto_nome,banca_sigla,ano,orgao_cargo,modalidade,dificuldade,gerada_por_ia,questao_alternativas(letra,texto,ordem)";
const DETAIL_COLUMNS = "id,codigo,enunciado,texto_associado,disciplina_slug,disciplina_nome,assunto_nome,banca_sigla,ano,orgao_cargo,modalidade,dificuldade,gerada_por_ia,comentario_professor,gabarito_oficial,questao_alternativas(letra,texto,ordem,correta,justificativa_alternativa)";

function requireDatabase() {
  if (!isSupabaseConfigured()) {
    const error = new Error("O banco de questões está indisponível. Configure o Supabase para continuar.");
    error.status = 503;
    throw error;
  }
  return getSupabaseAdmin();
}

function applyFilters(query, filters = {}) {
  if (filters.disciplina) query = query.eq("disciplina_slug", filters.disciplina);
  if (filters.assunto) query = query.ilike("assunto_nome", filters.assunto);
  if (filters.banca) query = query.eq("banca_sigla", filters.banca);
  if (filters.ano) query = query.eq("ano", Number(filters.ano));
  if (filters.dificuldade) query = query.eq("dificuldade", filters.dificuldade);
  if (filters.busca) {
    const term = String(filters.busca).replace(/[^\p{L}\p{N}\s#-]/gu, " ").trim();
    if (term) query = query.or(`enunciado.ilike.%${term}%,codigo.ilike.%${term}%`);
  }
  return query.eq("ativa", true).eq("anulada", false);
}

async function listQuestions(filters, userId) {
  const db = requireDatabase();
  const page = Number(filters.pagina) || 1;
  const perPage = Number(filters.porPagina) || 10;
  const start = (page - 1) * perPage;
  const { data, error, count } = await applyFilters(
    db.from("questoes").select(PUBLIC_COLUMNS, { count: "exact" }), filters,
  ).order("codigo", { ascending: true }).range(start, start + perPage - 1);
  if (error) throw error;

  const questions = data || [];
  let answeredIds = new Set();
  if (questions.length) {
    const { data: attempts, error: attemptError } = await db
      .from("question_attempts").select("questao_uuid")
      .eq("user_id", userId).in("questao_uuid", questions.map((q) => q.id));
    if (attemptError) throw attemptError;
    answeredIds = new Set((attempts || []).map((attempt) => attempt.questao_uuid));
  }

  return {
    questoes: questions.map((q) => ({
      id: q.id,
      codigo: q.codigo,
      enunciado: q.enunciado,
      texto_associado: q.texto_associado,
      disciplina: q.disciplina_nome,
      assunto: q.assunto_nome,
      banca: q.banca_sigla,
      ano: q.ano,
      orgao_cargo: q.orgao_cargo,
      modalidade: q.modalidade,
      dificuldade: q.dificuldade,
      geradaPorIa: q.gerada_por_ia,
      jaRespondida: answeredIds.has(q.id),
      alternativas: (q.questao_alternativas || []).sort((a, b) => a.ordem - b.ordem)
        .map(({ letra, texto }) => ({ letra, texto })),
    })),
    total: count || 0,
    pagina: page,
    porPagina: perPage,
  };
}

async function listFilters() {
  const db = requireDatabase();
  const { data, error } = await db.from("questoes")
    .select("disciplina_slug,assunto_nome,banca_sigla,ano,dificuldade")
    .eq("ativa", true).eq("anulada", false).limit(10000);
  if (error) throw error;
  const distinct = (key) => [...new Set((data || []).map((row) => row[key]).filter((value) => value != null))].sort();
  return { disciplinas: distinct("disciplina_slug"), assuntos: distinct("assunto_nome"), bancas: distinct("banca_sigla"), anos: distinct("ano"), dificuldades: distinct("dificuldade") };
}

async function getQuestion(id, { includeAnswer = false } = {}) {
  const db = requireDatabase();
  const columns = includeAnswer ? DETAIL_COLUMNS : PUBLIC_COLUMNS;
  const { data, error } = await db.from("questoes").select(columns)
    .eq("id", id).eq("ativa", true).eq("anulada", false).maybeSingle();
  if (error) throw error;
  return data;
}

async function answerQuestion(userId, questionId, resposta, tempoGastoSegundos) {
  const db = requireDatabase();
  const { data, error } = await db.rpc("fn_registrar_resposta_questao", {
    p_user_id: userId,
    p_questao_id: questionId,
    p_resposta: resposta,
    p_tempo_gasto_segundos: tempoGastoSegundos,
  });
  if (error) throw error;
  return Array.isArray(data) ? data[0] : data;
}

async function favoriteQuestion(userId, questionId) {
  const db = requireDatabase();
  const { error } = await db.from("questao_favoritos")
    .upsert({ user_id: userId, questao_id: questionId, pasta: "Geral" }, { onConflict: "user_id,questao_id" });
  if (error) throw error;
  return true;
}

module.exports = { listQuestions, listFilters, getQuestion, answerQuestion, favoriteQuestion, requireDatabase };
