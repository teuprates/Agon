const test = require("node:test");
const assert = require("node:assert");
process.env.NODE_ENV = "test";

const {
  classifyTopicDifficulty,
  computeSummary,
  getStudentDashboardMetrics,
} = require("../services/analyticsService");

const databaseService = require("../services/database");
const { GeminiProvider } = require("../services/aiProvider");
const {
  sanitizeInput,
  ensureCurrentUserMessage,
  buildQuestionContextPrompt,
  ZUKA_SYSTEM_PROMPT,
} = require("../services/zukaService");

// Inicializa banco de dados para testes em modo local
databaseService.initDatabase();

test("Regras de Classificação de Dificuldade (Thresholds)", () => {
  // Menos de 5 respostas válidas => dados_insuficientes
  const r1 = classifyTopicDifficulty(4, 80);
  assert.strictEqual(r1.codigo, "dados_insuficientes");

  const r2 = classifyTopicDifficulty(0, 0);
  assert.strictEqual(r2.codigo, "dados_insuficientes");

  // >= 5 respostas e taxaErro >= 60% => alta
  const r3 = classifyTopicDifficulty(5, 60);
  assert.strictEqual(r3.codigo, "alta");

  const r4 = classifyTopicDifficulty(20, 75);
  assert.strictEqual(r4.codigo, "alta");

  // >= 5 respostas e taxaErro entre 35% e 59% => moderada
  const r5 = classifyTopicDifficulty(5, 35);
  assert.strictEqual(r5.codigo, "moderada");

  const r6 = classifyTopicDifficulty(10, 50);
  assert.strictEqual(r6.codigo, "moderada");

  // >= 5 respostas e taxaErro < 35% => em_desenvolvimento (bom desempenho)
  const r7 = classifyTopicDifficulty(10, 20);
  assert.strictEqual(r7.codigo, "em_desenvolvimento");

  const r8 = classifyTopicDifficulty(8, 0);
  assert.strictEqual(r8.codigo, "em_desenvolvimento");
});

test("Cálculo de Estatísticas Resumidas (computeSummary)", () => {
  const attempts = [
    { acertou: true, tempoGastoSegundos: 30 },
    { acertou: true, tempoGastoSegundos: 40 },
    { acertou: false, tempoGastoSegundos: 50 },
    { acertou: true, tempoGastoSegundos: 40 },
  ];

  const summary = computeSummary(attempts);
  assert.strictEqual(summary.total, 4);
  assert.strictEqual(summary.acertos, 3);
  assert.strictEqual(summary.erros, 1);
  assert.strictEqual(summary.taxaAcerto, 75);
  assert.strictEqual(summary.taxaErro, 25);
  assert.strictEqual(summary.tempoMedio, 40);
});

test("Persistência de Tentativa de Questão e Atualização de Tópico", async () => {
  const testUserId = "test_user_" + Date.now();
  const attempt = await databaseService.saveQuestionAttempt({
    userId: testUserId,
    questionId: "TEST_Q1",
    disciplina: "Direito Constitucional",
    assunto: "Direitos Fundamentais",
    respostaSelecionada: "A",
    respostaCorreta: "A",
    acertou: true,
    tempoGastoSegundos: 25,
    banca: "Cebraspe",
    ano: "2024",
  });

  assert.ok(attempt.id);
  assert.strictEqual(attempt.userId, testUserId);
  assert.strictEqual(attempt.acertou, true);

  const history = await databaseService.getQuestionAttempts(testUserId);
  assert.strictEqual(history.length, 1);
  assert.strictEqual(history[0].questionId, "TEST_Q1");

  const topicStats = await databaseService.getStudentTopicStats(testUserId);
  assert.strictEqual(topicStats.length, 1);
  assert.strictEqual(topicStats[0].totalRespondidas, 1);
  assert.strictEqual(topicStats[0].totalAcertos, 1);
});

test("Isolamento Estrito de Dados entre Estudantes Diferentes", async () => {
  const studentA = "student_alpha_" + Date.now();
  const studentB = "student_beta_" + Date.now();

  // Student A records attempts
  await databaseService.saveQuestionAttempt({
    userId: studentA,
    questionId: "Q_A1",
    disciplina: "Português",
    assunto: "Crase",
    respostaSelecionada: "B",
    respostaCorreta: "B",
    acertou: true,
  });

  // Student B records attempts
  await databaseService.saveQuestionAttempt({
    userId: studentB,
    questionId: "Q_B1",
    disciplina: "Informática",
    assunto: "Redes",
    respostaSelecionada: "C",
    respostaCorreta: "D",
    acertou: false,
  });

  const attemptsA = await databaseService.getQuestionAttempts(studentA);
  const attemptsB = await databaseService.getQuestionAttempts(studentB);

  assert.strictEqual(attemptsA.length, 1);
  assert.strictEqual(attemptsA[0].questionId, "Q_A1");

  assert.strictEqual(attemptsB.length, 1);
  assert.strictEqual(attemptsB[0].questionId, "Q_B1");

  // Metrics isolation
  const metricsA = await getStudentDashboardMetrics(studentA);
  const metricsB = await getStudentDashboardMetrics(studentB);

  assert.strictEqual(metricsA.indicadoresGerais.totalRespondidas, 1);
  assert.strictEqual(metricsA.indicadoresGerais.totalAcertos, 1);

  assert.strictEqual(metricsB.indicadoresGerais.totalRespondidas, 1);
  assert.strictEqual(metricsB.indicadoresGerais.totalAcertos, 0);
  assert.strictEqual(metricsB.indicadoresGerais.totalErros, 1);
});

test("Higienização de Entrada e Limite de Caracteres (sanitizeInput)", () => {
  const normal = sanitizeInput("  Como estudar para a PF?  ");
  assert.strictEqual(normal, "Como estudar para a PF?");

  const huge = "a".repeat(5000);
  const sanitized = sanitizeInput(huge, 4000);
  assert.strictEqual(sanitized.length, 4000);

  const empty = sanitizeInput(null);
  assert.strictEqual(empty, "");
});

test("Formatação de Contexto de Questão com Gabarito Oficial", () => {
  const ctx = {
    questionId: "Q#9999",
    disciplina: "Direito Administrativo",
    assunto: "Poder de Polícia",
    banca: "Cebraspe",
    ano: "2024",
    concurso: "Polícia Federal",
    enunciado: "O poder de polícia administrativa incide sobre bens, direitos e atividades.",
    alternativas: [
      { letra: "C", texto: "Certo" },
      { letra: "E", texto: "Errado" },
    ],
    gabaritoOficial: "C",
    respostaSelecionada: "E",
    comentarioOficial: "Item correto nos termos do art. 78 do CTN.",
  };

  const formatted = buildQuestionContextPrompt(ctx);
  assert.ok(formatted.includes("Direito Administrativo"));
  assert.ok(formatted.includes("Poder de Polícia"));
  assert.ok(formatted.includes("GABARITO OFICIAL CADASTRADO]: Alternativa C"));
  assert.ok(formatted.includes("[RESPOSTA MARCADA PELO ESTUDANTE]: Alternativa E"));
  assert.ok(formatted.includes("[STATUS]: O estudante ERROU"));
  assert.ok(formatted.toLowerCase().includes("comentário oficial"));
});

test("Histórico vazio ainda inclui a mensagem atual para a IA", () => {
  const current = ensureCurrentUserMessage([], "Explique a questão.", { disciplina: "Direito" });
  assert.strictEqual(current.length, 1);
  assert.strictEqual(current[0].role, "user");
  assert.strictEqual(current[0].conteudo, "Explique a questão.");
  assert.deepStrictEqual(current[0].contextoQuestao, { disciplina: "Direito" });
});

test("Gemini rejeita histórico vazio antes de chamar a API", async () => {
  const provider = new GeminiProvider("test-api-key");
  await assert.rejects(
    () => provider.generateResponse({ systemInstruction: "test", messages: [] }),
    (err) => {
      assert.strictEqual(err.code, "EMPTY_CONTENTS");
      assert.strictEqual(err.status, 400);
      return true;
    }
  );
});

test("Tratamento de Provedor de IA sem Chave Configurada", async () => {
  const unconfiguredProvider = new GeminiProvider("");
  assert.strictEqual(unconfiguredProvider.isConfigured(), false);

  await assert.rejects(
    async () => {
      await unconfiguredProvider.generateResponse({
        systemInstruction: "test",
        messages: [{ role: "user", content: "oi" }],
      });
    },
    (err) => {
      assert.strictEqual(err.code, "KEY_MISSING");
      assert.strictEqual(err.status, 503);
      return true;
    }
  );
});

const app = require("../server");

test("Private pages and data APIs require authentication without a guest identity", async () => {
  const server = app.listen(0);
  const baseUrl = `http://localhost:${server.address().port}`;
  try {
    const root = await fetch(baseUrl, { redirect: "manual" });
    assert.strictEqual(root.status, 200);
    assert.match(await root.text(), /Agon/i);
    for (const path of ["/dashboard", "/index.html", "/ia-tutor.html"]) {
      const response = await fetch(`${baseUrl}${path}`, { redirect: "manual" });
      assert.strictEqual(response.status, 302, `${path} must require login`);
      assert.strictEqual(response.headers.get("location"), "/login");
    }
    for (const path of ["/api/zuka/status", "/api/zuka/conversas", "/api/questoes/historico", "/api/desempenho/estatisticas", "/api/planos-estudo/recomendacoes", "/api/dashboard/resumo"]) {
      const response = await fetch(`${baseUrl}${path}`);
      assert.strictEqual(response.status, 401, `${path} must require login`);
    }
    const callback = await fetch(baseUrl + "/auth/google/callback");
    assert.strictEqual(callback.status, 200);
    assert.match(await callback.text(), /google-auth-callback/);
    const googleScript = await fetch(baseUrl + "/js/google-auth.js");
    assert.strictEqual(googleScript.status, 200);
    assert.match(await googleScript.text(), /buildGoogleOAuthOptions/);
    const googleOptions = await fetch(baseUrl + "/js/google-auth-options.mjs");
    assert.strictEqual(googleOptions.status, 200);
    assert.match(await googleOptions.text(), /select_account/);
    const googleConfig = await fetch(baseUrl + "/api/auth/google/config");
    assert.strictEqual(googleConfig.status, 503);
    const googleSession = await fetch(baseUrl + "/api/auth/google/session", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ access_token: "fake-token" }),
    });
    assert.strictEqual(googleSession.status, 503);

    const shortPassword = await fetch(baseUrl + "/api/cadastrar", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nome: "Teste", email: "short@example.com", senha: "1234567", telefone: "11999999999" }),
    });
    assert.strictEqual(shortPassword.status, 400);
    assert.match((await shortPassword.json()).erro, /8 caracteres/);

    const invalidEmail = await fetch(baseUrl + "/api/cadastrar", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nome: "Teste", email: "email-invalido", senha: "senha-segura-123", telefone: "11999999999" }),
    });
    assert.strictEqual(invalidEmail.status, 400);

    const testEmail = `student-${Date.now()}@example.com`;
    const registration = await fetch(baseUrl + "/api/cadastrar", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        nome: "Conta de teste", email: testEmail, senha: "senha-segura-123", telefone: "11999999999",
        tipo_usuario: "professor", tipo_assinatura: "premium",
      }),
    });
    assert.strictEqual(registration.status, 201);
    const registered = await databaseService.findUserByEmail(testEmail);
    assert.strictEqual(registered.tipo_usuario, "aluno");
    assert.strictEqual(registered.tipo_assinatura, "gratuito");

    const secondEmail = `student-isolation-${Date.now()}@example.com`;
    const secondRegistration = await fetch(baseUrl + "/api/cadastrar", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nome: "Segundo estudante", email: secondEmail, senha: "senha-segura-456", telefone: "11999999998" }),
    });
    assert.strictEqual(secondRegistration.status, 201);

    const loginFor = async (email) => fetch(baseUrl + "/api/login", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, senha: "senha-segura-123" }),
    });
    const firstLogin = await loginFor(testEmail);
    assert.strictEqual(firstLogin.status, 200);
    const firstCookie = firstLogin.headers.get("set-cookie")?.match(/agon\.sid=[^;]+/)?.[0];
    assert.ok(firstCookie);

    const secondLogin = await fetch(baseUrl + "/api/login", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: secondEmail, senha: "senha-segura-456" }),
    });
    assert.strictEqual(secondLogin.status, 200);
    const secondCookie = secondLogin.headers.get("set-cookie")?.match(/agon\.sid=[^;]+/)?.[0];
    assert.ok(secondCookie);

    const answered = await fetch(baseUrl + "/api/questoes/responder", {
      method: "POST", headers: { "Content-Type": "application/json", cookie: firstCookie },
      body: JSON.stringify({ questionId: "private-question", disciplina: "Português", respostaSelecionada: "A", respostaCorreta: "A" }),
    });
    assert.strictEqual(answered.status, 201);
    const ownHistory = await fetch(baseUrl + "/api/questoes/historico?questionId=private-question", { headers: { cookie: firstCookie } });
    const otherHistory = await fetch(baseUrl + "/api/questoes/historico?questionId=private-question", { headers: { cookie: secondCookie } });
    assert.strictEqual((await ownHistory.json()).total, 1);
    assert.strictEqual((await otherHistory.json()).total, 0);

    const dashboardSummary = await fetch(baseUrl + "/api/dashboard/resumo", { headers: { cookie: firstCookie } });
    assert.strictEqual(dashboardSummary.status, 200);
    const dashboardData = await dashboardSummary.json();
    assert.strictEqual(dashboardData.estudanteId, registered.id);
    assert.strictEqual(dashboardData.indicadoresGerais.totalRespondidas, 1);
    assert.equal(dashboardData.atividadesRecentes[0].subtitulo, "Português • Geral");

    const createdConversation = await fetch(baseUrl + "/api/zuka/conversas", {
      method: "POST", headers: { "Content-Type": "application/json", cookie: firstCookie },
      body: JSON.stringify({ titulo: "Conversa privada de teste" }),
    });
    assert.strictEqual(createdConversation.status, 201);
    const conversation = await createdConversation.json();
    const ownConversation = await fetch(baseUrl + `/api/zuka/conversas/${conversation.id}`, { headers: { cookie: firstCookie } });
    const otherConversation = await fetch(baseUrl + `/api/zuka/conversas/${conversation.id}`, { headers: { cookie: secondCookie } });
    assert.strictEqual(ownConversation.status, 200);
    assert.strictEqual(otherConversation.status, 404);

    let limitedLogin;
    for (let attempt = 0; attempt < 11; attempt += 1) {
      limitedLogin = await fetch(baseUrl + "/api/login", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: "missing@example.com", senha: "senha-incorreta" }),
      });
    }
    assert.strictEqual(limitedLogin.status, 429);

    const auth = await fetch(`${baseUrl}/api/check-auth`);
    assert.deepStrictEqual(await auth.json(), { autenticado: false });
    assert.strictEqual(auth.headers.has("set-cookie"), false);
    assert.strictEqual((await fetch(`${baseUrl}/login`)).status, 200);
    assert.strictEqual((await fetch(`${baseUrl}/api/supabase/status`)).status, 200);
  } finally {
    server.close();
  }
});
