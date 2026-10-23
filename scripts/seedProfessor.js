require("dotenv").config();
const bcrypt = require("bcryptjs");
const databaseService = require("../services/database");
const { isSupabaseConfigured, getSupabaseAdmin } = require("../services/supabaseClient");

const email = process.env.PROFESSOR_TEST_EMAIL?.trim().toLowerCase();
const password = process.env.PROFESSOR_TEST_PASSWORD;
const name = process.env.PROFESSOR_TEST_NAME?.trim() || "Conta de demonstração";

async function seedProfessor() {
  if (!isSupabaseConfigured()) throw new Error("Configure as credenciais server-side do Supabase antes de criar a conta de teste.");
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("PROFESSOR_TEST_EMAIL deve conter um e-mail válido.");
  if (!password || password.length < 16) throw new Error("PROFESSOR_TEST_PASSWORD deve ter pelo menos 16 caracteres.");

  databaseService.initDatabase();
  const existing = await databaseService.findUserByEmail(email);
  const user = await databaseService.saveUser({
    id: existing?.id,
    nome: name,
    email,
    senha: await bcrypt.hash(password, 12),
    telefone: existing?.telefone || null,
    tipo_usuario: "aluno",
    tipo_assinatura: "gratuito",
    pontos_gamificacao: Math.max(0, Number(existing?.pontos_gamificacao) || 0),
  });

  const subjects = [
    { disciplina: "Direito Constitucional", assunto: "Direitos fundamentais", correct: 5 },
    { disciplina: "Direito Administrativo", assunto: "Atos administrativos", correct: 4 },
    { disciplina: "Língua Portuguesa", assunto: "Interpretação de texto", correct: 6 },
    { disciplina: "Informática", assunto: "Segurança da informação", correct: 3 },
    { disciplina: "Raciocínio Lógico", assunto: "Proposições", correct: 6 },
  ];
  const attempts = await databaseService.getQuestionAttempts(user.id);
  const existingIds = new Set(attempts.map((item) => item.questionId));
  const seededQuestionIds = [];
  for (const subject of subjects) {
    for (let i = 1; i <= 8; i += 1) {
      const questionId = `PROF_SEED_${subject.disciplina.toUpperCase().replace(/[^A-Z0-9]+/g, "_")}_${i}`;
      seededQuestionIds.push(questionId);
      if (existingIds.has(questionId)) continue;
      const acertou = i <= subject.correct;
      await databaseService.saveQuestionAttempt({
        userId: user.id,
        questionId,
        disciplina: subject.disciplina,
        assunto: subject.assunto,
        respostaSelecionada: acertou ? "A" : "B",
        respostaCorreta: "A",
        acertou,
        tempoGastoSegundos: 35 + i * 3,
        origem: "cadastrada",
        banca: "Demonstração",
        ano: String(new Date().getFullYear()),
      });
    }
  }

  const conversationTitle = "Boas-vindas à Zuka";
  const conversations = await databaseService.getConversations(user.id);
  if (!conversations.some((item) => item.titulo === conversationTitle)) {
    const conversation = await databaseService.createConversation(user.id, conversationTitle);
    await databaseService.addMessage(user.id, conversation.id, {
      role: "user",
      conteudo: "Como posso organizar meus estudos para esta semana?",
    });
    await databaseService.addMessage(user.id, conversation.id, {
      role: "model",
      conteudo: "Comece revisando os assuntos em que teve mais erros e distribua blocos curtos ao longo da semana. Esta mensagem inicial é demonstrativa.",
    });
  }

  const recommendations = await databaseService.getStudyRecommendations(user.id);
  if (!recommendations.some((item) => item.titulo === "Revisar Segurança da Informação")) {
    await databaseService.saveStudyRecommendation(user.id, {
      titulo: "Revisar Segurança da Informação",
      descricao: "Plano de exemplo criado para a conta de avaliação do professor.",
      disciplina: "Informática",
      assunto: "Segurança da informação",
      prioridade: "alta",
      tipo: "revisao",
    });
  }

  const supabase = getSupabaseAdmin();
  const [persistedUser, persistedAttempts, persistedConversation, persistedPlan] = await Promise.all([
    supabase.from("usuarios").select("id").eq("id", user.id).maybeSingle(),
    supabase.from("question_attempts").select("question_id", { count: "exact", head: true }).eq("user_id", user.id).in("question_id", seededQuestionIds),
    supabase.from("ai_conversations").select("id").eq("user_id", user.id).eq("titulo", conversationTitle).maybeSingle(),
    supabase.from("study_recommendations").select("id").eq("user_id", user.id).eq("titulo", "Revisar Segurança da Informação").maybeSingle(),
  ]);
  for (const result of [persistedUser, persistedAttempts, persistedConversation, persistedPlan]) {
    if (result.error) throw result.error;
  }
  if (!persistedUser.data || persistedAttempts.count !== 40 || !persistedConversation.data || !persistedPlan.data) {
    throw new Error("A conferência no Supabase não encontrou todos os dados da conta de avaliação.");
  }

  console.log("Conta de avaliação preparada no Supabase. Não imprima nem compartilhe as credenciais definidas no ambiente.");
}

seedProfessor().catch((error) => {
  console.error("Não foi possível preparar a conta de avaliação:", error.message);
  process.exitCode = 1;
});
