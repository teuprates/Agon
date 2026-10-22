/**
 * Camada de Acesso a Dados do Projeto AGON
 * Suporta persistência oficial no Supabase e fallback local para desenvolvimento
 */

const fs = require("fs");
const path = require("path");
const { isSupabaseConfigured, getSupabaseAdmin } = require("./supabaseClient");

const DATA_DIR = path.join(__dirname, "..", "data");
const LOCAL_DB_FILE = path.join(DATA_DIR, "local_db.json");

// Estrutura padrão da base local persistente
const DEFAULT_STORE = {
  usuarios: {},
  question_attempts: [],
  student_topic_stats: {}, // key: `${userId}_${disciplina}_${assunto}`
  ai_conversations: {},    // key: conversationId
  ai_messages: [],         // array de mensagens
  study_recommendations: []
};

let memoryStore = { ...DEFAULT_STORE };
let isSupabaseActive = false;

/**
 * Carrega a base local do disco para garantir persistência mesmo em modo offline/sem Supabase
 */
function loadLocalDb() {
  try {
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    if (fs.existsSync(LOCAL_DB_FILE)) {
      const raw = fs.readFileSync(LOCAL_DB_FILE, "utf-8");
      memoryStore = { ...DEFAULT_STORE, ...JSON.parse(raw) };
    } else {
      saveLocalDb();
    }
  } catch (err) {
    console.error("[DATABASE] Erro ao carregar banco local JSON:", err.message);
    memoryStore = { ...DEFAULT_STORE };
  }
}

/**
 * Salva a base local no disco
 */
function saveLocalDb() {
  try {
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    fs.writeFileSync(LOCAL_DB_FILE, JSON.stringify(memoryStore, null, 2), "utf-8");
  } catch (err) {
    console.error("[DATABASE] Erro ao salvar banco local JSON:", err.message);
  }
}

/**
 * Inicializa a camada de banco de dados
 */
function initDatabase() {
  loadLocalDb();
  isSupabaseActive = isSupabaseConfigured();

  if (isSupabaseActive) {
    console.log("[DATABASE] Inicializado. Motor ativo: Supabase Postgres Cloud ⚡");
  } else {
    console.log("[DATABASE] Inicializado. Motor ativo: Arquivo JSON Local Persistente ⚡ (Aguardando chaves no .env)");
  }
}

function getAdmin() {
  return getSupabaseAdmin();
}

// -----------------------------------------------------------------------------
// USUÁRIOS
// -----------------------------------------------------------------------------
async function findUserByEmail(email) {
  if (!email) return null;
  const normalizedEmail = email.toLowerCase().trim();

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("usuarios")
        .select("*")
        .ilike("email", normalizedEmail)
        .maybeSingle();

      if (error) {
        console.warn("[SUPABASE] Aviso ao buscar usuário por e-mail:", error.message);
      } else if (data) {
        return data;
      }
    } catch (err) {
      console.error("[SUPABASE ERRO findUserByEmail]:", err.message);
    }
  }
  for (const [id, user] of Object.entries(memoryStore.usuarios)) {
    if (user.email === normalizedEmail) {
      return { id, ...user };
    }
  }
  return null;
}

async function findUserById(id) {
  if (!id) return null;

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("usuarios")
        .select("*")
        .eq("id", id)
        .maybeSingle();

      if (error) {
        console.warn("[SUPABASE] Aviso ao buscar usuário por id:", error.message);
      } else if (data) {
        return data;
      }
    } catch (err) {
      console.error("[SUPABASE ERRO findUserById]:", err.message);
    }
  }
  const user = memoryStore.usuarios[id];
  return user ? { id, ...user } : null;
}

async function saveUser(userData) {
  const normalizedEmail = (userData.email || "").toLowerCase().trim();
  const id = userData.id || ("user_" + Date.now() + "_" + Math.floor(Math.random() * 1000));

  const record = {
    id,
    nome: userData.nome,
    email: normalizedEmail,
    senha: userData.senha || null,
    telefone: userData.telefone || null,
    tipo_usuario: userData.tipo_usuario || "aluno",
    tipo_assinatura: userData.tipo_assinatura || "gratuito",
    pontos_gamificacao: Number(userData.pontos_gamificacao) || 0,
    concurso_alvo: userData.concurso_alvo || "Geral",
    horas_semanais: Number(userData.horas_semanais) || 15,
    criado_em: userData.criado_em || new Date().toISOString(),
    atualizado_em: new Date().toISOString(),
  };

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("usuarios")
        .upsert(record)
        .select()
        .single();

      if (!error && data) {
        return data;
      }
      if (error) {
        console.warn("[SUPABASE] Fallback local em saveUser:", error.message);
      }
    } catch (err) {
      console.error("[SUPABASE ERRO saveUser]:", err.message);
    }
  }
  memoryStore.usuarios[id] = record;
  saveLocalDb();
  return record;
}

// -----------------------------------------------------------------------------
// QUESTION ATTEMPTS (Tentativas de Questões)
// -----------------------------------------------------------------------------
async function saveQuestionAttempt({
  userId,
  questionId,
  disciplina,
  assunto = "Geral",
  subassunto = "",
  respostaSelecionada,
  respostaCorreta,
  acertou,
  tempoGastoSegundos = 0,
  origem = "oficial",
  banca = "",
  ano = ""
}) {
  if (!userId || !questionId) {
    throw new Error("userId e questionId são obrigatórios");
  }

  const now = new Date();
  const attemptId = `att_${userId}_${questionId}_${Date.now()}`;

  // Obter número da tentativa anterior
  let tentativaNum = 1;
  const previousAttempts = await getQuestionAttempts(userId, { questionId });
  if (previousAttempts && previousAttempts.length > 0) {
    tentativaNum = previousAttempts.length + 1;
  }

  const attemptRecord = {
    id: attemptId,
    userId,
    questionId: String(questionId),
    disciplina: disciplina || "Geral",
    assunto: assunto || "Geral",
    subassunto: subassunto || "",
    respostaSelecionada: String(respostaSelecionada || ""),
    respostaCorreta: String(respostaCorreta || ""),
    acertou: Boolean(acertou),
    tempoGastoSegundos: Number(tempoGastoSegundos) || 0,
    origem: origem || "oficial",
    banca: banca || "",
    ano: ano || "",
    tentativaNum,
    criadoEm: now.toISOString(),
  };

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const supabaseRow = {
        id: attemptRecord.id,
        user_id: attemptRecord.userId,
        question_id: attemptRecord.questionId,
        disciplina: attemptRecord.disciplina,
        assunto: attemptRecord.assunto,
        subassunto: attemptRecord.subassunto,
        resposta_selecionada: attemptRecord.respostaSelecionada,
        resposta_correta: attemptRecord.respostaCorreta,
        acertou: attemptRecord.acertou,
        tempo_gasto_segundos: attemptRecord.tempoGastoSegundos,
        origem: attemptRecord.origem,
        banca: attemptRecord.banca,
        ano: attemptRecord.ano,
        tentativa_num: attemptRecord.tentativaNum,
        criado_em: attemptRecord.criadoEm,
      };

      const { error } = await supabase.from("question_attempts").insert(supabaseRow);
      if (error) {
        console.warn("[SUPABASE] Falha ao inserir tentativa de questão (fallback local):", error.message);
        memoryStore.question_attempts.push(attemptRecord);
        saveLocalDb();
      }
    } catch (err) {
      console.error("[SUPABASE ERRO saveQuestionAttempt]:", err.message);
      memoryStore.question_attempts.push(attemptRecord);
      saveLocalDb();
    }
  } else {
    memoryStore.question_attempts.push(attemptRecord);
    saveLocalDb();
  }

  // Atualiza as estatísticas agregadas por disciplina/assunto
  await updateStudentTopicStats({
    userId,
    disciplina: attemptRecord.disciplina,
    assunto: attemptRecord.assunto,
    acertou: attemptRecord.acertou,
    tempoGastoSegundos: attemptRecord.tempoGastoSegundos
  });

  return attemptRecord;
}

async function getQuestionAttempts(userId, filter = {}) {
  if (!userId) return [];

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      let query = supabase
        .from("question_attempts")
        .select("*")
        .eq("user_id", userId)
        .order("criado_em", { ascending: false });

      if (filter.questionId) {
        query = query.eq("question_id", String(filter.questionId));
      }
      if (filter.disciplina && filter.disciplina !== "todas") {
        query = query.eq("disciplina", filter.disciplina);
      }

      const { data, error } = await query;
      if (!error && data) {
        return data.map((row) => ({
          id: row.id,
          userId: row.user_id,
          questionId: row.question_id,
          disciplina: row.disciplina,
          assunto: row.assunto,
          subassunto: row.subassunto,
          respostaSelecionada: row.resposta_selecionada,
          respostaCorreta: row.resposta_correta,
          acertou: row.acertou,
          tempoGastoSegundos: row.tempo_gasto_segundos,
          origem: row.origem,
          banca: row.banca,
          ano: row.ano,
          tentativaNum: row.tentativa_num,
          criadoEm: row.criado_em,
        }));
      }
      if (error) {
        console.warn("[SUPABASE] Falha ao consultar tentativas (fallback local):", error.message);
      }
    } catch (err) {
      console.error("[SUPABASE ERRO getQuestionAttempts]:", err.message);
    }
  }

  return memoryStore.question_attempts
    .filter((att) => {
      if (att.userId !== userId) return false;
      if (filter.questionId && att.questionId !== String(filter.questionId)) return false;
      if (filter.disciplina && filter.disciplina !== "todas" && att.disciplina !== filter.disciplina) return false;
      return true;
    })
    .sort((a, b) => new Date(b.criadoEm || 0) - new Date(a.criadoEm || 0));
}

// -----------------------------------------------------------------------------
// STUDENT TOPIC STATS (Estatísticas por Estudante e Assunto)
// -----------------------------------------------------------------------------
function normalizeKey(str) {
  return String(str || "Geral").toLowerCase().replace(/[^a-z0-9]/g, "_");
}

function calculateDifficultyClassification(totalRespondidas, taxaErro) {
  if (totalRespondidas < 5) {
    return "dados_insuficientes";
  }
  if (taxaErro >= 60) {
    return "alta";
  }
  if (taxaErro >= 35) {
    return "moderada";
  }
  return "em_desenvolvimento";
}

async function updateStudentTopicStats({ userId, disciplina, assunto, acertou, tempoGastoSegundos = 0 }) {
  const normDisc = normalizeKey(disciplina);
  const normAssunto = normalizeKey(assunto);
  const statKey = `${userId}_${normDisc}_${normAssunto}`;

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data: existing } = await supabase
        .from("student_topic_stats")
        .select("*")
        .eq("id", statKey)
        .maybeSingle();

      let totalRespondidas = (existing?.total_respondidas || 0) + 1;
      let totalAcertos = (existing?.total_acertos || 0) + (acertou ? 1 : 0);
      let totalErros = (existing?.total_erros || 0) + (acertou ? 0 : 1);
      let tempoTotalSegundos = (existing?.tempo_total_segundos || 0) + (Number(tempoGastoSegundos) || 0);
      let taxaAcerto = Math.round((totalAcertos / totalRespondidas) * 100);
      let taxaErro = 100 - taxaAcerto;
      let classificacaoDificuldade = calculateDifficultyClassification(totalRespondidas, taxaErro);
      let ultimaAtividade = new Date().toISOString();

      const supabaseRow = {
        id: statKey,
        user_id: userId,
        disciplina: disciplina || "Geral",
        assunto: assunto || "Geral",
        total_respondidas: totalRespondidas,
        total_acertos: totalAcertos,
        total_erros: totalErros,
        tempo_total_segundos: tempoTotalSegundos,
        taxa_acerto: taxaAcerto,
        taxa_erro: taxaErro,
        classificacao_dificuldade: classificacaoDificuldade,
        ultima_atividade: ultimaAtividade,
      };

      const { error: upsertError } = await supabase.from("student_topic_stats").upsert(supabaseRow);

      if (!upsertError) {
        return {
          userId,
          disciplina,
          assunto,
          totalRespondidas,
          totalAcertos,
          totalErros,
          tempoTotalSegundos,
          taxaAcerto,
          taxaErro,
          classificacaoDificuldade,
          ultimaAtividade,
        };
      }
      console.warn("[SUPABASE] Falha em updateStudentTopicStats (fallback local):", upsertError.message);
    } catch (err) {
      console.error("[SUPABASE ERRO updateStudentTopicStats]:", err.message);
    }
  }

  // Fallback Local
  let current = memoryStore.student_topic_stats[statKey] || {
    userId,
    disciplina,
    assunto,
    totalRespondidas: 0,
    totalAcertos: 0,
    totalErros: 0,
    tempoTotalSegundos: 0,
    taxaAcerto: 0,
    taxaErro: 0,
    classificacaoDificuldade: "dados_insuficientes",
    ultimaAtividade: new Date().toISOString()
  };

  current.totalRespondidas += 1;
  if (acertou) {
    current.totalAcertos += 1;
  } else {
    current.totalErros += 1;
  }
  current.tempoTotalSegundos += Number(tempoGastoSegundos) || 0;
  current.taxaAcerto = Math.round((current.totalAcertos / current.totalRespondidas) * 100);
  current.taxaErro = 100 - current.taxaAcerto;
  current.classificacaoDificuldade = calculateDifficultyClassification(current.totalRespondidas, current.taxaErro);
  current.ultimaAtividade = new Date().toISOString();

  memoryStore.student_topic_stats[statKey] = current;
  saveLocalDb();
  return current;
}

async function getStudentTopicStats(userId) {
  if (!userId) return [];

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("student_topic_stats")
        .select("*")
        .eq("user_id", userId);

      if (!error && data) {
        return data.map((row) => ({
          id: row.id,
          userId: row.user_id,
          disciplina: row.disciplina,
          assunto: row.assunto,
          totalRespondidas: row.total_respondidas,
          totalAcertos: row.total_acertos,
          totalErros: row.total_erros,
          tempoTotalSegundos: row.tempo_total_segundos,
          taxaAcerto: row.taxa_acerto,
          taxaErro: row.taxa_erro,
          classificacaoDificuldade: row.classificacao_dificuldade,
          ultimaAtividade: row.ultima_atividade,
        }));
      }
      if (error) {
        console.warn("[SUPABASE] Falha ao consultar estatísticas por assunto (fallback local):", error.message);
      }
    } catch (err) {
      console.error("[SUPABASE ERRO getStudentTopicStats]:", err.message);
    }
  }
  return Object.values(memoryStore.student_topic_stats).filter((stat) => stat.userId === userId);
}

// -----------------------------------------------------------------------------
// AI CONVERSATIONS & MESSAGES (Zuka IA)
// -----------------------------------------------------------------------------
async function createConversation(userId, titulo = "Nova conversa com Zuka IA") {
  const convId = "conv_" + Date.now() + "_" + Math.floor(Math.random() * 1000);
  const now = new Date().toISOString();
  const conv = {
    id: convId,
    userId,
    titulo: titulo.trim().slice(0, 100),
    criadoEm: now,
    atualizadoEm: now,
  };

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { error } = await supabase.from("ai_conversations").insert({
        id: conv.id,
        user_id: conv.userId,
        titulo: conv.titulo,
        criado_em: conv.criadoEm,
        atualizado_em: conv.atualizadoEm,
      });
      if (!error) return conv;
    } catch (err) {
      console.error("[SUPABASE ERRO createConversation]:", err.message);
    }
  }
  memoryStore.ai_conversations[convId] = conv;
  saveLocalDb();
  return conv;
}

async function getConversations(userId) {
  if (!userId) return [];

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("ai_conversations")
        .select("*")
        .eq("user_id", userId)
        .order("atualizado_em", { ascending: false });

      if (!error && data) {
        return data.map((row) => ({
          id: row.id,
          userId: row.user_id,
          titulo: row.titulo,
          criadoEm: row.criado_em,
          atualizadoEm: row.atualizado_em,
        }));
      }
    } catch (err) {
      console.error("[SUPABASE ERRO getConversations]:", err.message);
    }
  }
  return Object.values(memoryStore.ai_conversations)
    .filter((c) => c.userId === userId)
    .sort((a, b) => new Date(b.atualizadoEm || 0) - new Date(a.atualizadoEm || 0));
}

async function getConversationById(userId, conversationId) {
  if (!conversationId) return null;

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("ai_conversations")
        .select("*")
        .eq("id", conversationId)
        .eq("user_id", userId)
        .maybeSingle();

      if (!error && data) {
        return {
          id: data.id,
          userId: data.user_id,
          titulo: data.titulo,
          criadoEm: data.criado_em,
          atualizadoEm: data.atualizado_em,
        };
      }
    } catch (err) {
      console.error("[SUPABASE ERRO getConversationById]:", err.message);
    }
  }
  const conv = memoryStore.ai_conversations[conversationId];
  if (!conv || conv.userId !== userId) return null;
  return conv;
}

async function deleteConversation(userId, conversationId) {
  const conv = await getConversationById(userId, conversationId);
  if (!conv) return false;

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { error } = await supabase.from("ai_conversations").delete().eq("id", conversationId).eq("user_id", userId);
      if (!error) return true;
    } catch (err) {
      console.error("[SUPABASE ERRO deleteConversation]:", err.message);
    }
  }
  delete memoryStore.ai_conversations[conversationId];
  memoryStore.ai_messages = memoryStore.ai_messages.filter((m) => m.conversationId !== conversationId);
  saveLocalDb();
  return true;
}

async function addMessage(userId, conversationId, { role, conteudo, contextoQuestao = null }) {
  const msgId = "msg_" + Date.now() + "_" + Math.floor(Math.random() * 1000);
  const now = new Date().toISOString();

  const msg = {
    id: msgId,
    conversationId,
    userId,
    role: role === "model" ? "model" : "user",
    conteudo: String(conteudo || ""),
    contextoQuestao: contextoQuestao || null,
    criadoEm: now,
  };

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { error } = await supabase.from("ai_messages").insert({
        id: msg.id,
        conversation_id: msg.conversationId,
        user_id: msg.userId,
        role: msg.role,
        conteudo: msg.conteudo,
        contexto_questao: msg.contextoQuestao,
        criado_em: msg.criadoEm,
      });

      if (!error) {
        await supabase
          .from("ai_conversations")
          .update({ atualizado_em: now })
          .eq("id", conversationId);
        return msg;
      }
    } catch (err) {
      console.error("[SUPABASE ERRO addMessage]:", err.message);
    }
  }
  memoryStore.ai_messages.push(msg);
  if (memoryStore.ai_conversations[conversationId]) {
    memoryStore.ai_conversations[conversationId].atualizadoEm = now;
  }
  saveLocalDb();
  return msg;
}

async function getMessages(userId, conversationId, limitCount = 50) {
  const conv = await getConversationById(userId, conversationId);
  if (!conv) return [];

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("ai_messages")
        .select("*")
        .eq("conversation_id", conversationId)
        .eq("user_id", userId)
        .order("criado_em", { ascending: true })
        .limit(limitCount);

      if (!error && data) {
        return data.map((row) => ({
          id: row.id,
          conversationId: row.conversation_id,
          userId: row.user_id,
          role: row.role,
          conteudo: row.conteudo,
          contextoQuestao: row.contexto_questao,
          criadoEm: row.criado_em,
        }));
      }
    } catch (err) {
      console.error("[SUPABASE ERRO getMessages]:", err.message);
    }
  }
  return memoryStore.ai_messages
    .filter((m) => m.conversationId === conversationId && m.userId === userId)
    .sort((a, b) => new Date(a.criadoEm || 0) - new Date(b.criadoEm || 0))
    .slice(-limitCount);
}

// -----------------------------------------------------------------------------
// STUDY RECOMMENDATIONS (Recomendações de Estudo)
// -----------------------------------------------------------------------------
async function saveStudyRecommendation(userId, recData) {
  const recId = "rec_" + Date.now() + "_" + Math.floor(Math.random() * 1000);
  const record = {
    id: recId,
    userId,
    titulo: recData.titulo,
    descricao: recData.descricao,
    disciplina: recData.disciplina || "Geral",
    assunto: recData.assunto || "Geral",
    prioridade: recData.prioridade || "media",
    tipo: recData.tipo || "revisao",
    status: "pendente",
    geradoPor: recData.geradoPor || "regras_estatisticas",
    criadoEm: new Date().toISOString(),
  };

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { error } = await supabase.from("study_recommendations").insert({
        id: record.id,
        user_id: record.userId,
        titulo: record.titulo,
        descricao: record.descricao,
        disciplina: record.disciplina,
        assunto: record.assunto,
        prioridade: record.prioridade,
        tipo: record.tipo,
        status: record.status,
        gerado_por: record.geradoPor,
        criado_em: record.criadoEm,
      });
      if (!error) return record;
    } catch (err) {
      console.error("[SUPABASE ERRO saveStudyRecommendation]:", err.message);
    }
  }
  memoryStore.study_recommendations.push(record);
  saveLocalDb();
  return record;
}

async function getStudyRecommendations(userId) {
  if (!userId) return [];

  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("study_recommendations")
        .select("*")
        .eq("user_id", userId)
        .order("criado_em", { ascending: false });

      if (!error && data) {
        return data.map((row) => ({
          id: row.id,
          userId: row.user_id,
          titulo: row.titulo,
          descricao: row.descricao,
          disciplina: row.disciplina,
          assunto: row.assunto,
          prioridade: row.prioridade,
          tipo: row.tipo,
          status: row.status,
          geradoPor: row.gerado_por,
          criadoEm: row.criado_em,
        }));
      }
    } catch (err) {
      console.error("[SUPABASE ERRO getStudyRecommendations]:", err.message);
    }
  }
  return memoryStore.study_recommendations
    .filter((r) => r.userId === userId)
    .sort((a, b) => new Date(b.criadoEm || 0) - new Date(a.criadoEm || 0));
}

async function updateStudyRecommendationStatus(userId, recId, status) {
  if (isSupabaseConfigured()) {
    try {
      const supabase = getAdmin();
      const { data, error } = await supabase
        .from("study_recommendations")
        .update({ status, atualizado_em: new Date().toISOString() })
        .eq("id", recId)
        .eq("user_id", userId)
        .select()
        .maybeSingle();

      if (!error && data) {
        return {
          id: data.id,
          userId: data.user_id,
          titulo: data.titulo,
          descricao: data.descricao,
          disciplina: data.disciplina,
          assunto: data.assunto,
          prioridade: data.prioridade,
          tipo: data.tipo,
          status: data.status,
          geradoPor: data.gerado_por,
          criadoEm: data.criado_em,
        };
      }
    } catch (err) {
      console.error("[SUPABASE ERRO updateStudyRecommendationStatus]:", err.message);
    }
  }
  const item = memoryStore.study_recommendations.find((r) => r.id === recId && r.userId === userId);
  if (!item) return null;
  item.status = status;
  item.atualizadoEm = new Date().toISOString();
  saveLocalDb();
  return item;
}

module.exports = {
  initDatabase,
  findUserByEmail,
  findUserById,
  saveUser,
  saveQuestionAttempt,
  getQuestionAttempts,
  updateStudentTopicStats,
  getStudentTopicStats,
  calculateDifficultyClassification,
  createConversation,
  getConversations,
  getConversationById,
  deleteConversation,
  addMessage,
  getMessages,
  saveStudyRecommendation,
  getStudyRecommendations,
  updateStudyRecommendationStatus,
};
