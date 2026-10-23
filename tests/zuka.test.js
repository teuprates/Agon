const test = require("node:test");
const assert = require("node:assert");

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

test("Integração HTTP Endpoints da Zuka IA e Dashboard", async () => {
  const server = app.listen(0);
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;

  try {
    const statusRes = await fetch(`${baseUrl}/api/zuka/status`);
    assert.strictEqual(statusRes.status, 200);
    const statusData = await statusRes.json();
    assert.strictEqual(statusData.provedor, "Google Gemini");
    assert.strictEqual(typeof statusData.configurada, "boolean");

    // Teste de status do Supabase
    const supaRes = await fetch(`${baseUrl}/api/supabase/status`);
    assert.strictEqual(supaRes.status, 200);
    const supaData = await supaRes.json();
    assert.strictEqual(typeof supaData.configurado, "boolean");
    assert.ok(typeof supaData.mensagem === "string");

    // Inicia sessão para obter cookie
    const authRes = await fetch(`${baseUrl}/api/check-auth`);
    const rawCookie = authRes.headers.get("set-cookie");
    const cookie = rawCookie ? rawCookie.split(";")[0] : "";
    const sessionHeaders = {
      "Content-Type": "application/json",
      "Cookie": cookie
    };

    // Teste de criação e leitura de conversa com cookie da sessão
    const convRes = await fetch(`${baseUrl}/api/zuka/conversas`, {
      method: "POST",
      headers: sessionHeaders,
      body: JSON.stringify({ titulo: "Conversa Teste Automatizado" }),
    });
    assert.strictEqual(convRes.status, 201);
    const conv = await convRes.json();
    assert.ok(conv.id);

    // Teste de leitura das mensagens da conversa
    const getConvRes = await fetch(`${baseUrl}/api/zuka/conversas/${conv.id}`, {
      headers: sessionHeaders,
    });
    assert.strictEqual(getConvRes.status, 200);
    const convDetails = await getConvRes.json();
    assert.strictEqual(convDetails.conversa.id, conv.id);

    // Teste de exclusão da conversa
    const delRes = await fetch(`${baseUrl}/api/zuka/conversas/${conv.id}`, {
      method: "DELETE",
      headers: sessionHeaders,
    });
    assert.strictEqual(delRes.status, 200);

    // Teste de endpoint de estatísticas
    const statsRes = await fetch(`${baseUrl}/api/desempenho/estatisticas`, {
      headers: sessionHeaders,
    });
    assert.strictEqual(statsRes.status, 200);
    const stats = await statsRes.json();
    assert.ok(stats.indicadoresGerais);
    assert.ok(Array.isArray(stats.desempenhoPorDisciplina));
    assert.ok(Array.isArray(stats.mapaDificuldades));
  } finally {
    server.close();
  }
});
