const express = require("express");
const path = require("path");
const fs = require("fs");
const bcrypt = require("bcryptjs");
const session = require("express-session");
const helmet = require("helmet");
const { rateLimit } = require("express-rate-limit");
const SupabaseSessionStore = require("./services/supabaseSessionStore");
if (process.env.NODE_ENV !== "test") require("dotenv").config();

// Serviços Zuka IA, Banco de Dados, Supabase e Analytics
const databaseService = require("./services/database");
const { isSupabaseConfigured, getSupabaseStatus, getSupabaseAdmin, getSupabasePublicConfig } = require("./services/supabaseClient");
const { getAIProvider } = require("./services/aiProvider");
const zukaService = require("./services/zukaService");
const analyticsService = require("./services/analyticsService");
const { requireAuth, requireAuthApi, requireRole } = require("./middleware/auth");
const createQuestionRouter = require("./routes/questoes");
const createAdminRouter = require("./routes/admin");

const app = express();
app.set("trust proxy", process.env.NODE_ENV === "production" ? 1 : false);

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
  console.log("  4. Preencha no arquivo .env: SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY e SUPABASE_SECRET_KEY.");
  console.log("  5. Aplique as migrações SQL disponíveis na pasta 'supabase/migrations/'.");
  console.log("==================================================================");
}

// Middlewares
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
// { index: false } impede que o static intercepte a raiz com index.html
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));

if (process.env.NODE_ENV === "production") {
  if (!process.env.SESSION_SECRET || process.env.SESSION_SECRET.length < 32) throw new Error("SESSION_SECRET must have at least 32 characters in production.");
  if (!isSupabaseConfigured()) throw new Error("Supabase is required in production for persistence and sessions.");
} else if (!process.env.SESSION_SECRET) {
  console.warn("SESSION_SECRET is not set; the development-only fallback must never be used in production.");
}

// Configuração da sessão
app.use(
  session({
    name: "agon.sid",
    secret: process.env.SESSION_SECRET || "development-only-session-secret-change-me",
    store: isSupabaseConfigured() ? new SupabaseSessionStore({ cleanupIntervalMs: 60 * 60 * 1000 }) : undefined,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      maxAge: 24 * 60 * 60 * 1000, // 24 horas
    },
  })
);

// Middleware para verificar autenticação de páginas
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: "draft-8", legacyHeaders: false });
const loginLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: "draft-8", legacyHeaders: false });
const googleSessionLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: "draft-8", legacyHeaders: false });
const privatePages = new Set(["index", "dashboard", "aulas", "planos-estudo", "materiais", "estudos", "questoes", "simulados", "desempenho", "ia-tutor", "comunidade", "conquistas", "configuracoes", "em-breve"]);
const publicPages = new Set(["home", "login", "cadastro"]);
app.use((req, res, next) => {
  const page = req.path.match(/^\/([^/]+)\.html$/i)?.[1]?.toLowerCase();
  if (page && privatePages.has(page)) {
    if (!req.session?.user) return res.redirect("/login");
    res.set("Cache-Control", "private, no-store");
  }
  if (page && !privatePages.has(page) && !publicPages.has(page)) return res.sendStatus(404);
  next();
});
app.use(["/api/questoes", "/api/desempenho", "/api/planos-estudo", "/api/dashboard"], requireAuthApi);
app.use("/api/questoes", createQuestionRouter());
app.use("/api/admin", requireAuthApi, requireRole("professor", "admin"), createAdminRouter());

// Keep legacy .html links working while ensuring private HTML is never a Vercel CDN asset.
privatePages.forEach((page) => {
  app.get(`/${page}.html`, requireAuth, (_req, res) => {
    res.redirect(page === "index" || page === "dashboard" ? "/dashboard" : `/${page}`);
  });
});

// Rotas para páginas principais
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/home", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/landing", (req, res) => {
  res.redirect(301, "/");
});

app.get("/index", requireAuth, (_req, res) => res.redirect(301, "/dashboard"));

app.get("/dashboard", (req, res) => {
  if (!req.session.user) return res.redirect("/login");
  res.set("Cache-Control", "private, no-store");
  res.sendFile(path.join(__dirname, "protected-pages", "index.html"));
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

app.get("/admin/questoes", requireAuth, requireRole("professor", "admin"), (_req, res) => {
  res.sendFile(path.join(__dirname, "protected-pages", "admin-questoes.html"));
});

app.get("/servicos", requireAuth, (_req, res) => res.redirect(301, "/materiais"));

app.get("/sobre", requireAuth, (_req, res) => res.redirect(301, "/comunidade"));

// Rota protegida - só acessa se estiver logado
app.get("/setores", requireAuth, (_req, res) => res.redirect(301, "/estudos"));

// Rotas para todas as páginas da plataforma Agon
const agonPages = [
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
    if (privatePages.has(page) && !req.session.user) return res.redirect("/login");
    if (privatePages.has(page)) res.set("Cache-Control", "private, no-store");
    if (page === "questoes") {
      res.set("Content-Security-Policy", [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com",
        "font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com data:",
        "img-src 'self' data:",
        "connect-src 'self'",
        "object-src 'none'",
        "base-uri 'self'",
        "frame-ancestors 'self'",
      ].join("; "));
    }
    res.sendFile(path.join(__dirname, privatePages.has(page) ? "protected-pages" : "public", `${page}.html`));
  });
});

app.get("/auth/google/callback", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "auth-google-callback.html"));
});

app.use(express.static(path.join(__dirname, "public"), { index: false, dotfiles: "deny" }));

// ==========================================
// APIS DE AUTENTICAÇÃO E SUPABASE
// ==========================================

// Status da conexão com Supabase
app.get("/api/supabase/status", (req, res) => {
  res.json(getSupabaseStatus());
});

// The publishable key is safe to expose to the browser; the secret key stays server-side.
app.get("/api/auth/google/config", (_req, res) => {
  const config = getSupabasePublicConfig();
  if (!config) return res.status(503).json({ erro: "Login Google indisponível: configuração pública do Supabase ausente." });
  res.set("Cache-Control", "no-store").json(config);
});

app.post("/api/auth/google/session", googleSessionLimiter, async (req, res) => {
  const accessToken = req.body?.access_token;
  if (typeof accessToken !== "string" || !accessToken) {
    return res.status(400).json({ erro: "Token de autenticação ausente." });
  }
  if (!isSupabaseConfigured()) {
    return res.status(503).json({ erro: "Login Google indisponível no servidor." });
  }

  try {
    const { data, error } = await getSupabaseAdmin().auth.getUser(accessToken);
    if (error || !data?.user?.email || !(data.user.email_confirmed_at || data.user.confirmed_at)) {
      return res.status(401).json({ erro: "Não foi possível validar a conta Google." });
    }

    const email = data.user.email.toLowerCase().trim();
    let user = await databaseService.findUserByEmail(email);
    if (!user) {
      const { data: created, error: saveError } = await getSupabaseAdmin()
        .from("usuarios")
        .insert({
          id: data.user.id,
          nome: data.user.user_metadata?.full_name || data.user.user_metadata?.name || email.split("@")[0],
          email,
          tipo_usuario: "aluno",
          tipo_assinatura: "gratuito",
          pontos_gamificacao: 0,
        })
        .select("*")
        .single();
      if (saveError) throw saveError;
      user = created;
    }

    const sessionUser = {
      id: user.id,
      nome: user.nome,
      email: user.email,
      telefone: user.telefone,
      avatar_url: user.avatar_url || null,
      tipo_usuario: user.tipo_usuario || "aluno",
      tipo_assinatura: user.tipo_assinatura || "gratuito",
      pontos_gamificacao: user.pontos_gamificacao || 0,
    };
    await new Promise((resolve, reject) => req.session.regenerate((err) => err ? reject(err) : resolve()));
    req.session.user = sessionUser;
    await new Promise((resolve, reject) => req.session.save((err) => err ? reject(err) : resolve()));
    res.set("Cache-Control", "no-store").json({ sucesso: true, usuario: sessionUser });
  } catch (error) {
    console.error("[GOOGLE AUTH] Falha ao validar ou persistir a conta:", error.message);
    res.status(500).json({ erro: "Não foi possível concluir o login com Google." });
  }
});

// API - Cadastro
app.post("/api/cadastrar", loginLimiter, async (req, res) => {
  const {
    nome,
    email,
    senha,
    telefone,
    tipo_usuario: _tipoUsuarioIgnorado,
    tipo_assinatura: _tipoAssinaturaIgnorada,
  } = req.body;

  if (typeof nome !== "string" || typeof email !== "string" || typeof senha !== "string" || typeof telefone !== "string" || !nome.trim() || !email.trim() || !senha || !telefone.trim()) {
    console.info("[CADASTRO] Campos obrigatórios não informados.");
    return res.status(400).json({ erro: "Todos os campos são obrigatórios." });
  }

  if (senha.length < 8) {
    console.info("[CADASTRO] Senha rejeitada por estar abaixo do mínimo.");
    return res.status(400).json({ erro: "A senha deve ter pelo menos 8 caracteres." });
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    return res.status(400).json({ erro: "Informe um e-mail válido." });
  }

  try {
    const existing = await databaseService.findUserByEmail(email);
    if (existing) {
      console.info("[CADASTRO] Tentativa com e-mail já cadastrado.");
      return res.status(400).json({ erro: "Este e-mail já está cadastrado." });
    }

    const saltRounds = 10;
    const hash = await bcrypt.hash(senha, saltRounds);

    const novoUsuario = await databaseService.saveUser({
      nome,
      email: email.toLowerCase().trim(),
      senha: hash,
      telefone,
      tipo_usuario: "aluno",
      tipo_assinatura: "gratuito",
      pontos_gamificacao: 0,
    });

    console.info(`[CADASTRO] Usuário criado. ID: ${novoUsuario.id}`);
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
app.post("/api/login", loginLimiter, async (req, res) => {
  const { email, senha } = req.body;

  if (!email || !senha) {
    console.log("[LOGIN FALHOU]: E-mail ou senha não fornecidos.");
    return res.status(400).json({ erro: "E-mail e senha são obrigatórios." });
  }

  try {
    const user = await databaseService.findUserByEmail(email);
    if (!user) {
      console.info("[LOGIN] Credenciais rejeitadas.");
      return res.status(401).json({ erro: "E-mail ou senha inválidos." });
    }

    const isMatch = await bcrypt.compare(senha, user.senha);
    if (!isMatch) {
      console.info("[LOGIN] Credenciais rejeitadas.");
      return res.status(401).json({ erro: "E-mail ou senha inválidos." });
    }

    const sessionUser = {
      id: user.id,
      nome: user.nome,
      email: user.email,
      telefone: user.telefone,
      avatar_url: user.avatar_url || null,
      tipo_usuario: user.tipo_usuario || "aluno",
      tipo_assinatura: user.tipo_assinatura || "gratuito",
      pontos_gamificacao: user.pontos_gamificacao || 0,
    };

    await new Promise((resolve, reject) => req.session.regenerate((err) => err ? reject(err) : resolve()));
    req.session.user = sessionUser;

    console.info(`[LOGIN] Sessão iniciada. ID: ${user.id}`);

    res.status(200).json({
      sucesso: "Login efetuado com sucesso!",
      usuario: sessionUser,
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
    res.clearCookie("agon.sid");
    res.status(200).json({ sucesso: "Logout realizado com sucesso!" });
  });
});

// API - Buscar dados completos do usuário
app.get("/api/user/:id", requireAuthApi, async (req, res) => {
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
  if (!req.session.user) return res.status(200).json({ autenticado: false });
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
  return res.status(200).json({ autenticado: false });
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
app.post("/api/zuka/chat", requireAuthApi, async (req, res) => {
  const student = req.session.user;
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
app.get("/api/zuka/conversas", requireAuthApi, async (req, res) => {
  const student = req.session.user;
  try {
    const list = await databaseService.getConversations(student.id);
    res.json({ conversas: list });
  } catch (err) {
    console.error("[CONVERSAS ERRO]:", err);
    res.status(500).json({ erro: "Erro ao buscar histórico de conversas." });
  }
});

// Criar nova conversa
app.post("/api/zuka/conversas", requireAuthApi, async (req, res) => {
  const student = req.session.user;
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
app.get("/api/zuka/conversas/:id", requireAuthApi, async (req, res) => {
  const student = req.session.user;
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
app.delete("/api/zuka/conversas/:id", requireAuthApi, async (req, res) => {
  const student = req.session.user;
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

// Obter histórico de tentativas do estudante
app.get("/api/questoes/historico", async (req, res) => {
  const student = req.session.user;
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

function calculateStudyStreak(attempts) {
  const activeDates = new Set(attempts.map((attempt) => {
    const timestamp = new Date(attempt.criadoEm || 0);
    return Number.isNaN(timestamp.getTime()) ? null : timestamp.toISOString().slice(0, 10);
  }).filter(Boolean));
  const cursor = new Date();
  cursor.setUTCHours(0, 0, 0, 0);
  const today = cursor.toISOString().slice(0, 10);
  cursor.setUTCDate(cursor.getUTCDate() - 1);
  if (!activeDates.has(today) && !activeDates.has(cursor.toISOString().slice(0, 10))) return 0;
  if (activeDates.has(today)) cursor.setUTCDate(cursor.getUTCDate() + 1);

  let streak = 0;
  while (activeDates.has(cursor.toISOString().slice(0, 10))) {
    streak += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

app.get("/api/dashboard/resumo", async (req, res) => {
  const student = req.session.user;
  try {
    const [metrics, attempts, user] = await Promise.all([
      analyticsService.getStudentDashboardMetrics(student.id),
      databaseService.getQuestionAttempts(student.id),
      databaseService.findUserById(student.id),
    ]);

    let notifications = [];
    if (isSupabaseConfigured()) {
      const { data, error } = await getSupabaseAdmin()
        .from("notificacoes")
        .select("id, tipo, titulo, mensagem, icone, cor_tema, link_destino, lida, criado_em")
        .eq("user_id", student.id)
        .order("criado_em", { ascending: false })
        .limit(5);
      if (error) throw error;
      notifications = data || [];
    }

    const atividadesRecentes = attempts.slice(0, 5).map((attempt) => ({
      id: attempt.id,
      tipo: "questoes",
      titulo: "Questão respondida",
      subtitulo: [attempt.disciplina, attempt.assunto].filter(Boolean).join(" • ") || "Banco de questões",
      acertou: Boolean(attempt.acertou),
      criadoEm: attempt.criadoEm,
    }));
    const hojeSaoPaulo = new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(new Date());
    const questoesHoje = attempts.filter((attempt) => {
      const date = attempt.criadoEm ? new Date(attempt.criadoEm) : null;
      return date && !Number.isNaN(date.getTime()) &&
        new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(date) === hojeSaoPaulo;
    }).length;
    res.set("Cache-Control", "private, no-store").json({
      estudanteId: student.id,
      estudanteNome: student.nome,
      indicadoresGerais: metrics.indicadoresGerais,
      desempenhoPorDisciplina: metrics.desempenhoPorDisciplina,
      atividadesRecentes,
      notificacoes: {
        naoLidas: notifications.filter((item) => !item.lida).length,
        itens: notifications,
      },
      sequenciaDias: calculateStudyStreak(attempts),
      questoesHoje,
      pontosGamificacao: Number(user?.pontos_gamificacao) || 0,
      temDadosReais: metrics.temDadosReais,
    });
  } catch (err) {
    console.error("[DASHBOARD RESUMO ERRO]:", err.message);
    res.status(500).json({ erro: "Erro ao carregar o resumo do dashboard." });
  }
});

app.get("/api/desempenho/estatisticas", async (req, res) => {
  const student = req.session.user;
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
  const student = req.session.user;
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
  const student = req.session.user;
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
  const student = req.session.user;
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

// Health check usado pelos provedores de hospedagem.
app.get("/health", (_req, res) => res.status(200).json({ status: "ok" }));

module.exports = app;
