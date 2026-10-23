const test = require("node:test");
const assert = require("node:assert/strict");
process.env.NODE_ENV = "test";

const request = require("supertest");
const app = require("../app");

test("API de questões exige sessão e não aceita gabarito enviado pelo cliente", async () => {
  const unauthenticated = await request(app).get("/api/questoes");
  assert.equal(unauthenticated.status, 401);
  assert.match(unauthenticated.body.erro, /autenticação necessária/i);

  const agent = request.agent(app);
  const email = `questions-${Date.now()}@example.com`;
  const registration = await agent.post("/api/cadastrar").send({
    nome: "Aluna de teste",
    email,
    senha: "senha-segura-987",
    telefone: "11999999999",
    tipo_usuario: "administrador",
  });
  assert.equal(registration.status, 201);

  const login = await agent.post("/api/login").send({ email, senha: "senha-segura-987" });
  assert.equal(login.status, 200);
  assert.equal(login.body.usuario.tipo_usuario, "aluno");

  const forbiddenAdmin = await agent.get("/api/admin/questoes");
  assert.equal(forbiddenAdmin.status, 403);
  assert.match(forbiddenAdmin.body.erro, /permissão|permissao/i);

  const legacy = await agent.post("/api/questoes/responder").send({
    questionId: "fake-question",
    respostaSelecionada: "A",
    respostaCorreta: "A",
    acertou: true,
  });
  assert.equal(legacy.status, 410);

  const forged = await agent.post("/api/questoes/00000000-0000-4000-8000-000000000000/responder").send({
    resposta: "A",
    tempoGastoSegundos: 0,
    respostaCorreta: "A",
    acertou: true,
  });
  assert.equal(forged.status, 503, "Without Supabase, the endpoint must not record a client-asserted answer locally");
});

test("página de questões é protegida e carrega políticas CSP", async () => {
  const response = await request(app).get("/questoes");
  assert.equal(response.status, 302);

  const agent = request.agent(app);
  const email = `csp-${Date.now()}@example.com`;
  await agent.post("/api/cadastrar").send({ nome: "Teste CSP", email, senha: "senha-segura-123", telefone: "11999999999" });
  await agent.post("/api/login").send({ email, senha: "senha-segura-123" });
  const page = await agent.get("/questoes");
  assert.equal(page.status, 200);
  assert.match(page.headers["content-security-policy"], /script-src 'self'/);
  assert.match(page.text, /id="question-list"/);
});
