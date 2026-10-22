const express = require("express");
const bodyParser = require("body-parser");
const path = require("path");
const fs = require("fs");
const bcrypt = require("bcryptjs");
const session = require("express-session");
require("dotenv").config();

// Serviços Zuka IA, Banco de Dados, Supabase e Analytics
const databaseService = require("./services/database");
const { isSupabaseConfigured, getSupabaseStatus } = require("./services/supabaseClient");
const { getAIProvider } = require("./services/aiProvider");
const zukaService = require("./services/zukaService");
const analyticsService = require("./services/analyticsService");

const app = express();

// ==========================================
// CONFIGURAÇÃO DO SUPABASE / PERSISTÊNCIA
// ==========================================
databaseService.initDatabase();

if (!isSupabaseConfigured()) {
  console.log("==================================================================");
  console.log("ℹ️  AVISO DO SUPABASE:");
  console.log("As credenciais do Supabase ainda não foram configuradas no arquivo .env.");
  console.log("O servidor iniciou com armazenamento local persistente para testes.");
  console.log("Para conectar à sua conta Supabase:");
  console.log("  1. Acesse: https://supabase.com/dashboard");
  console.log("  2. Crie seu projeto e acesse 'Project Settings' > 'API'.");
  console.log("  3. Copie a Project URL, anon key e service_role key.");
  console.log("  4. Preencha no arquivo .env: SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY.");
  console.log("  5. Aplique as migrações SQL disponíveis na pasta 'supabase/migrations/'.");
  console.log("==================================================================");
}

// Middlewares
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
// { index: false } impede que o static intercepte a raiz com index.html
app.use(express.static(path.join(__dirname, "public"), { index: false }));

// Configuração da sessão
app.use(
  session({
    secret: process.env.SESSION_SECRET || "agon-secret-key-supabase-2026",
    resave: false,
    saveUninitialized: true,
    cookie: {
      secure: false,
      maxAge: 24 * 60 * 60 * 1000, // 24 horas
    },
  })
);

// Middleware para verificar autenticação de páginas
const requireAuth = (req, res, next) => {
  if (req.session.user) {
    next();
  } else {
    res.redirect("/login");
  }
};

/**
 * Obtém o usuário da sessão ou estabelece um identificador de estudante isolado.
 * Garante que o histórico nunca seja misturado entre sessões diferentes.
 */
function getActiveStudent(req) {
  if (req.session && req.session.user) {
    return req.session.user;
  }
  if (!req.session.guestStudent) {
    const guestId = "guest_" + (req.sessionID || Date.now());
    req.session.guestStudent = {
      id: guestId,
      nome: "Davi Brito (Estudante)",
      email: "davi.brito_agon@gmail.com",
      tipo_usuario: "aluno",
      tipo_assinatura: "premium",
      pontos_gamificacao: 150,
    };
  }
  return req.session.guestStudent;
}

// Rotas para páginas principais
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/home", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/landing", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/dashboard", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.get("/login", (req, res) => {
  if (req.session.user) {
    return res.redirect("/dashboard");
  }
  res.sendFile(path.join(__dirname, "public", "login.html"));
});

app.get("/cadastro", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "cadastro.html"));
});

app.get("/servicos", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "materiais.html"));
});

app.get("/sobre", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "comunidade.html"));
});

// Rota protegida - só acessa se estiver logado
app.get("/setores", requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, "public", "estudos.html"));
});

// Rotas para todas as páginas da plataforma Agon
const agonPages = [
  "index",
  "home",
  "aulas",
  "planos-estudo",
  "materiais",
  "estudos",
  "questoes",
  "simulados",
  "desempenho",
  "ia-tutor",
  "comunidade",
  "conquistas",
  "configuracoes",
  "em-breve",
];

agonPages.forEach((page) => {
  app.get(`/${page}`, (req, res) => {
    res.sendFile(path.join(__dirname, "public", `${page}.html`));
  });
});

// ==========================================
// APIS DE AUTENTICAÇÃO E SUPABASE
// ==========================================

// Status da conexão com Supabase
app.get("/api/supabase/status", (req, res) => {
  res.json(getSupabaseStatus());
});

// API - Cadastro
app.post("/api/cadastrar", async (req, res) => {
  const {
    nome,
    email,
    senha,
    telefone,
    tipo_usuario = "aluno",
    tipo_assinatura = "gratuito",
  } = req.body;

  if (!nome || !email || !senha || !telefone) {
    console.log(`[CADASTRO FALHOU]: Campos obrigatórios faltando. Email: ${email || "N/A"}`);
    return res.status(400).json({ erro: "Todos os campos são obrigatórios." });
  }

  if (senha.length < 6) {
    console.log(`[CADASTRO FALHOU]: Senha muito curta. Email: ${email}`);
    return res.status(400).json({ erro: "A senha deve ter pelo menos 6 caracteres." });
  }

  try {
    const existing = await databaseService.findUserByEmail(email);
    if (existing) {
      console.log(`[CADASTRO FALHOU]: E-mail já cadastrado: ${email}`);
      return res.status(400).json({ erro: "Este e-mail já está cadastrado." });
    }

    const saltRounds = 10;
    const hash = await bcrypt.hash(senha, saltRounds);

    const novoUsuario = await databaseService.saveUser({
      nome,
      email: email.toLowerCase().trim(),
      senha: hash,
      telefone,
      tipo_usuario,
      tipo_assinatura,
      pontos_gamificacao: 0,
    });

    console.log(`[CADASTRO SUCESSO]: Usuário cadastrado ID: ${novoUsuario.id} (${email})`);
    return res.status(201).json({
      sucesso: "Usuário cadastrado com sucesso!",
      usuarioId: novoUsuario.id,
    });
  } catch (error) {
    console.error("[ERRO CADASTRO]:", error);
    return res.status(500).json({ erro: "Erro interno no servidor ao registrar usuário." });
  }
});

// API - Login
app.post("/api/login", async (req, res) => {
  const { email, senha } = req.body;

  if (!email || !senha) {
    console.log("[LOGIN FALHOU]: E-mail ou senha não fornecidos.");
    return res.status(400).json({ erro: "E-mail e senha são obrigatórios." });
  }

  try {
    const user = await databaseService.findUserByEmail(email);
    if (!user) {
      console.log(`[LOGIN FALHOU]: E-mail não encontrado: ${email}`);
      return res.status(401).json({ erro: "E-mail ou senha inválidos." });
    }

    const isMatch = await bcrypt.compare(senha, user.senha);
    if (!isMatch) {
      console.log(`[LOGIN FALHOU]: Senha inválida para: ${email}`);
      return res.status(401).json({ erro: "E-mail ou senha inválidos." });
    }

    req.session.user = {
      id: user.id,
      nome: user.nome,
      email: user.email,
      telefone: user.telefone,
      tipo_usuario: user.tipo_usuario || "aluno",
      tipo_assinatura: user.tipo_assinatura || "gratuito",
      pontos_gamificacao: user.pontos_gamificacao || 0,
    };

    console.log(`[LOGIN SUCESSO]: Usuário logado - ID: ${user.id}, Nome: ${user.nome}`);

    res.status(200).json({
      sucesso: "Login efetuado com sucesso!",
      usuario: req.session.user,
    });
  } catch (error) {
    console.error("[ERRO LOGIN]:", error);
    res.status(500).json({ erro: "Erro interno no servidor ao realizar login." });
  }
});

// API - Logout
app.post("/api/logout", (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      console.error("[ERRO SESSÃO]: Erro ao fazer logout:", err);
      return res.status(500).json({ erro: "Erro ao fazer logout." });
    }
    res.clearCookie("connect.sid");
    res.status(200).json({ sucesso: "Logout realizado com sucesso!" });
  });
});

app.get(["/logout", "/api/logout"], (req, res) => {
  if (req.session) {
    req.session.destroy(() => {
      res.clearCookie("connect.sid");
      res.redirect("/login.html");
    });
  } else {
    res.clearCookie("connect.sid");
    res.redirect("/login.html");
  }
});

// API - Buscar dados completos do usuário
app.get("/api/user/:id", requireAuth, async (req, res) => {
  const userId = req.params.id;

  if (userId !== req.session.user.id) {
    console.log(`[ACESSO NEGADO]: Usuário ${req.session.user.id} tentou acessar dados de ${userId}`);
    return res.status(403).json({ erro: "Acesso não autorizado." });
  }

  try {
    const user = await databaseService.findUserById(userId);
    if (!user) {
      return res.status(404).json({ erro: "Usuário não encontrado." });
    }
    const data = { ...user };
    delete data.senha;
    return res.status(200).json(data);
  } catch (err) {
    console.error("[ERRO BUSCAR USUÁRIO]:", err);
    res.status(500).json({ erro: "Erro interno ao buscar usuário." });
  }
});

// API - Verificar autenticação
app.get("/api/check-auth", async (req, res) => {
  const student = getActiveStudent(req);
  if (req.session.user) {
    try {
      const refreshed = await databaseService.findUserById(req.session.user.id);
      if (refreshed) {
        req.session.user = {
          id: refreshed.id,
          nome: refreshed.nome,
          email: refreshed.email,
          telefone: refreshed.telefone,
          tipo_usuario: refreshed.tipo_usuario || "aluno",
          tipo_assinatura: refreshed.tipo_assinatura || "gratuito",
          pontos_gamificacao: refreshed.pontos_gamificacao || 0,
        };
      }
    } catch (err) {
      console.warn("Aviso ao atualizar sessão do usuário:", err.message);
    }
    return res.status(200).json({ autenticado: true, usuario: req.session.user });
  }
  return res.status(200).json({ autenticado: false, usuarioConvidado: student });
});

// ==========================================
// APIS DA ZUKA IA (CHAT & TUTOR INTELIGENTE)
// ==========================================

// Rate limiting em memória para o chat da Zuka IA (20 requisições por minuto por estudante)
const zukaRateLimits = new Map();
function checkZukaRateLimit(userId) {
  const now = Date.now();
  const windowMs = 60 * 1000;
  const maxRequests = 20;
  const history = zukaRateLimits.get(userId) || [];
  const validHistory = history.filter((t) => now - t < windowMs);
  if (validHistory.length >= maxRequests) {
    return false;
  }
  validHistory.push(now);
  zukaRateLimits.set(userId, validHistory);
  return true;
}

// Status da integração com a IA
app.get("/api/zuka/status", (req, res) => {
  const aiProvider = getAIProvider();
  const isReady = aiProvider.isConfigured();
  res.json({
    configurada: isReady,
    provedor: aiProvider.getProviderName(),
    modelo: isReady ? aiProvider.getActiveModel() : null,
    mensagem: isReady
      ? "Zuka IA pronta para atender dúvidas com Google Gemini."
      : "Chave GEMINI_API_KEY não configurada no servidor (.env). Configure uma chave gratuita do Google AI Studio para ativar as respostas inteligentes.",
  });
});

// Enviar mensagem para a Zuka IA
app.post("/api/zuka/chat", async (req, res) => {
  const student = getActiveStudent(req);
  const { message, conversationId, questionContext } = req.body;

  if (!message || typeof message !== "string" || !message.trim()) {
    return res.status(400).json({ erro: "A mensagem é obrigatória e não pode estar vazia." });
  }

  if (message.length > 4000) {
    return res.status(400).json({ erro: "A mensagem excede o limite máximo permitido de 4.000 caracteres." });
  }

  // Controle de requisições por minuto
  if (!checkZukaRateLimit(student.id)) {
    return res.status(429).json({
      erro: "Você atingiu o limite de envio de mensagens por minuto. Aguarde alguns instantes antes de enviar uma nova dúvida.",
    });
  }

  try {
    const result = await zukaService.processUserMessage({
      userId: student.id,
      conversationId,
      messageText: message,
      questionContext,
    });
    return res.status(200).json(result);
  } catch (error) {
    console.error("[ZUKA CHAT ERRO]:", error.message);
    const status = error.status || 500;
    return res.status(status).json({
      erro: error.message || "Erro interno ao processar resposta com a Zuka IA.",
      codigo: error.code || "UNKNOWN_ERROR",
    });
  }
});

// Listar conversas do estudante
app.get("/api/zuka/conversas", async (req, res) => {
  const student = getActiveStudent(req);
  try {
    const list = await databaseService.getConversations(student.id);
    res.json({ conversas: list });
  } catch (err) {
    console.error("[CONVERSAS ERRO]:", err);
    res.status(500).json({ erro: "Erro ao buscar histórico de conversas." });
  }
});

// Criar nova conversa
app.post("/api/zuka/conversas", async (req, res) => {
  const student = getActiveStudent(req);
  const { titulo = "Nova conversa" } = req.body;
  try {
    const conv = await databaseService.createConversation(student.id, titulo);
    res.status(201).json(conv);
  } catch (err) {
    console.error("[NOVA CONVERSA ERRO]:", err);
    res.status(500).json({ erro: "Erro ao criar conversa." });
  }
});

// Buscar mensagens de uma conversa
app.get("/api/zuka/conversas/:id", async (req, res) => {
  const student = getActiveStudent(req);
  const convId = req.params.id;
  try {
    const conv = await databaseService.getConversationById(student.id, convId);
    if (!conv) {
      return res.status(404).json({ erro: "Conversa não encontrada ou não pertence a este usuário." });
    }
    const messages = await databaseService.getMessages(student.id, convId);
    res.json({ conversa: conv, mensagens: messages });
  } catch (err) {
    console.error("[MENSAGENS CONVERSA ERRO]:", err);
    res.status(500).json({ erro: "Erro ao recuperar mensagens." });
  }
});

// Excluir conversa
app.delete("/api/zuka/conversas/:id", async (req, res) => {
  const student = getActiveStudent(req);
  const convId = req.params.id;
  try {
    const success = await databaseService.deleteConversation(student.id, convId);
    if (!success) {
      return res.status(404).json({ erro: "Conversa não encontrada." });
    }
    res.json({ sucesso: true, mensagem: "Conversa removida com sucesso." });
  } catch (err) {
    console.error("[EXCLUIR CONVERSA ERRO]:", err);
    res.status(500).json({ erro: "Erro ao remover conversa." });
  }
});

// ==========================================
// APIS DE QUESTÕES & REGISTRO DE TENTATIVAS
// ==========================================

// Registrar resposta de questão pelo estudante
app.post("/api/questoes/responder", async (req, res) => {
  const student = getActiveStudent(req);
  const {
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
    ano = "",
  } = req.body;

  if (!questionId || respostaSelecionada === undefined) {
    return res.status(400).json({ erro: "questionId e respostaSelecionada são obrigatórios." });
  }

  // Determinar se acertou caso boolean não venha explícito
  const isAcerto =
    typeof acertou === "boolean"
      ? acertou
      : String(respostaSelecionada).trim().toUpperCase() === String(respostaCorreta || "").trim().toUpperCase();

  try {
    const attempt = await databaseService.saveQuestionAttempt({
      userId: student.id,
      questionId,
      disciplina: disciplina || "Geral",
      assunto: assunto || "Geral",
      subassunto,
      respostaSelecionada,
      respostaCorreta,
      acertou: isAcerto,
      tempoGastoSegundos: Number(tempoGastoSegundos) || 0,
      origem,
      banca,
      ano,
    });

    console.log(`[QUESTÃO RESPONDIDA]: Estudante ${student.id} respondeu ${questionId} - ${isAcerto ? "ACERTOU ✅" : "ERROU ❌"}`);

    return res.status(201).json({
      sucesso: true,
      acertou: isAcerto,
      tentativa: attempt,
    });
  } catch (err) {
    console.error("[REGISTRO RESPOSTA ERRO]:", err);
    return res.status(500).json({ erro: "Erro ao registrar tentativa de questão." });
  }
});

// Obter histórico de tentativas do estudante
app.get("/api/questoes/historico", async (req, res) => {
  const student = getActiveStudent(req);
  const { disciplina, questionId } = req.query;
  try {
    const list = await databaseService.getQuestionAttempts(student.id, { disciplina, questionId });
    res.json({ tentativas: list, total: list.length });
  } catch (err) {
    console.error("[HISTORICO TENTATIVAS ERRO]:", err);
    res.status(500).json({ erro: "Erro ao buscar histórico de questões." });
  }
});

// ==========================================
// APIS DE DESEMPENHO E ANALYTICS REAL
// ==========================================

app.get("/api/desempenho/estatisticas", async (req, res) => {
  const student = getActiveStudent(req);
  try {
    const metrics = await analyticsService.getStudentDashboardMetrics(student.id);
    res.json({
      estudanteId: student.id,
      estudanteNome: student.nome,
      ...metrics,
    });
  } catch (err) {
    console.error("[ESTATISTICAS ERRO]:", err);
    res.status(500).json({ erro: "Erro ao processar estatísticas do estudante." });
  }
});

// ==========================================
// APIS DE PLANOS DE ESTUDO & RECOMENDAÇÕES IA
// ==========================================

// Obter recomendações automáticas calculadas a partir dos dados reais
app.get("/api/planos-estudo/recomendacoes", async (req, res) => {
  const student = getActiveStudent(req);
  try {
    const metrics = await analyticsService.getStudentDashboardMetrics(student.id);
    const storedRecs = await databaseService.getStudyRecommendations(student.id);

    res.json({
      recomendacoesCalculadas: metrics.recomendacoesZuka,
      mapaDificuldades: metrics.mapaDificuldades,
      recomendacoesSalvas: storedRecs,
      temDadosReais: metrics.temDadosReais,
    });
  } catch (err) {
    console.error("[PLANO RECOMENDACOES ERRO]:", err);
    res.status(500).json({ erro: "Erro ao buscar recomendações de estudo." });
  }
});

// Gerar orientação inteligente de estudo via Zuka IA
app.post("/api/planos-estudo/gerar-ia", async (req, res) => {
  const student = getActiveStudent(req);
  const { concursoAlvo = "Polícia Federal", horasSemanais = 15 } = req.body;

  try {
    const guidance = await zukaService.generateIntelligentStudyGuidance({
      userId: student.id,
      concursoAlvo,
      horasSemanais: Number(horasSemanais) || 15,
    });
    res.json(guidance);
  } catch (err) {
    console.error("[GERAR PLANO IA ERRO]:", err);
    res.status(500).json({ erro: err.message || "Erro ao gerar plano de estudo com a Zuka IA." });
  }
});

// Atualizar status de uma recomendação
app.patch("/api/planos-estudo/recomendacoes/:id", async (req, res) => {
  const student = getActiveStudent(req);
  const { status } = req.body;
  if (!status || !["pendente", "em_andamento", "concluido"].includes(status)) {
    return res.status(400).json({ erro: "Status inválido." });
  }
  try {
    const updated = await databaseService.updateStudyRecommendationStatus(student.id, req.params.id, status);
    if (!updated) {
      return res.status(404).json({ erro: "Recomendação não encontrada." });
    }
    res.json(updated);
  } catch (err) {
    console.error("[ATUALIZAR RECOMENDACAO ERRO]:", err);
    res.status(500).json({ erro: "Erro ao atualizar recomendação." });
  }
});

// Tratamento de exceções e rejeições não tratadas (evita encerramento inesperado do processo)
process.on("uncaughtException", (err) => {
  console.error("⚠️  [UNCAUGHT EXCEPTION]:", err.message);
});

process.on("unhandledRejection", (reason) => {
  console.error("⚠️  [UNHANDLED REJECTION]:", reason);
});

// Inicialização do servidor com recuperação automática de porta ocupada
let currentPort = Number(process.env.PORT) || 3500;

function startServer(portToTry) {
  const server = app.listen(portToTry, () => {
    console.log(`=========================================`);
    console.log(`🚀 Servidor Agon rodando em http://localhost:${portToTry}`);
    console.log(`🌐 Supabase Status: ${isSupabaseConfigured() ? "Conectado ao Supabase na Nuvem ⚡" : "Modo Local (Aguardando Credenciais no .env) ⚡"}`);
    console.log(`🤖 Zuka IA: ${getAIProvider().isConfigured() ? "Ativa com Google Gemini ✨" : "Aguardando GEMINI_API_KEY no .env ⚡"}`);
    console.log(`=========================================`);
  });

  server.on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      console.warn(`\n⚠️  [PORTA OCUPADA]: A porta ${portToTry} já está em uso por outro processo.`);
      const nextPort = portToTry + 1;
      console.log(`👉 Tentando iniciar automaticamente na porta ${nextPort}...\n`);
      setTimeout(() => startServer(nextPort), 500);
    } else {
      console.error("❌ [ERRO SERVIDOR]:", err.message);
    }
  });
}

if (require.main === module) {
  startServer(currentPort);
}

module.exports = app;
