const db = require("./database");

// Limiares configuráveis para classificação de dificuldade
const DIFFICULTY_CONFIG = {
  MIN_RESPONSES_FOR_ANALYSIS: 5,
  HIGH_ERROR_THRESHOLD: 60,     // >= 60%
  MODERATE_ERROR_THRESHOLD: 35, // >= 35% e < 60%
};

/**
 * Calcula a classificação de dificuldade do assunto
 */
function classifyTopicDifficulty(totalRespondidas, taxaErro, config = DIFFICULTY_CONFIG) {
  if (!totalRespondidas || totalRespondidas < config.MIN_RESPONSES_FOR_ANALYSIS) {
    return {
      codigo: "dados_insuficientes",
      label: "Dados Insuficientes",
      descricao: `Menos de ${config.MIN_RESPONSES_FOR_ANALYSIS} questões respondidas. Resolva mais questões para análise confiável.`,
      cor: "gray"
    };
  }
  if (taxaErro >= config.HIGH_ERROR_THRESHOLD) {
    return {
      codigo: "alta",
      label: "Dificuldade Alta",
      descricao: `Taxa de erro crítica (${taxaErro}%). Prioridade máxima de estudo e revisão teórica.`,
      cor: "red"
    };
  }
  if (taxaErro >= config.MODERATE_ERROR_THRESHOLD) {
    return {
      codigo: "moderada",
      label: "Dificuldade Moderada",
      descricao: `Taxa de erro em atenção (${taxaErro}%). Recomendado reforço com resolução de questões.`,
      cor: "orange"
    };
  }
  return {
    codigo: "em_desenvolvimento",
    label: "Bom Desempenho",
    descricao: `Excelente aproveitamento (${100 - taxaErro}% de acertos). Mantenha revisões periódicas.`,
    cor: "green"
  };
}

/**
 * Agrupa tentativas em períodos de tempo
 */
function filterAttemptsByDays(attempts, daysAgo) {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - daysAgo);
  cutoff.setHours(0, 0, 0, 0);

  return attempts.filter(a => {
    const d = new Date(a.criadoEm || 0);
    return d >= cutoff;
  });
}

/**
 * Gera estatísticas de um subconjunto de tentativas
 */
function computeSummary(attempts) {
  const total = attempts.length;
  if (total === 0) {
    return { total: 0, acertos: 0, erros: 0, taxaAcerto: 0, taxaErro: 0, tempoMedio: 0 };
  }
  const acertos = attempts.filter(a => a.acertou).length;
  const erros = total - acertos;
  const taxaAcerto = Math.round((acertos / total) * 100);
  const taxaErro = 100 - taxaAcerto;

  const validTimes = attempts.filter(a => a.tempoGastoSegundos && a.tempoGastoSegundos > 0);
  const tempoMedio = validTimes.length > 0
    ? Math.round(validTimes.reduce((acc, a) => acc + a.tempoGastoSegundos, 0) / validTimes.length)
    : 0;

  return { total, acertos, erros, taxaAcerto, taxaErro, tempoMedio };
}

/**
 * Calcula todas as métricas reais para o dashboard do estudante
 */
async function getStudentDashboardMetrics(userId, customConfig = {}) {
  const config = { ...DIFFICULTY_CONFIG, ...customConfig };

  // Busca todas as tentativas reais do estudante
  const attempts = await db.getQuestionAttempts(userId);

  const overall = computeSummary(attempts);

  // Evolução últimos 7 e 30 dias
  const last7DaysAttempts = filterAttemptsByDays(attempts, 7);
  const last30DaysAttempts = filterAttemptsByDays(attempts, 30);

  // Período anterior de 7 dias (entre 7 e 14 dias atrás) para comparação
  const now = new Date();
  const d7 = new Date(now); d7.setDate(d7.getDate() - 7);
  const d14 = new Date(now); d14.setDate(d14.getDate() - 14);
  const prev7DaysAttempts = attempts.filter(a => {
    const d = new Date(a.criadoEm || 0);
    return d >= d14 && d < d7;
  });

  const statsLast7 = computeSummary(last7DaysAttempts);
  const statsPrev7 = computeSummary(prev7DaysAttempts);
  const statsLast30 = computeSummary(last30DaysAttempts);

  const evolucao7Dias = {
    atual: statsLast7.taxaAcerto,
    anterior: statsPrev7.taxaAcerto,
    diferencaPP: statsLast7.taxaAcerto - statsPrev7.taxaAcerto,
    questoesPeriodo: statsLast7.total,
  };

  // Desempenho por disciplina
  const byDisciplina = {};
  attempts.forEach(a => {
    const disc = a.disciplina || "Geral";
    if (!byDisciplina[disc]) {
      byDisciplina[disc] = { disciplina: disc, total: 0, acertos: 0, erros: 0, tempoTotal: 0 };
    }
    byDisciplina[disc].total += 1;
    if (a.acertou) byDisciplina[disc].acertos += 1;
    else byDisciplina[disc].erros += 1;
    byDisciplina[disc].tempoTotal += (a.tempoGastoSegundos || 0);
  });

  const disciplinasRanking = Object.values(byDisciplina).map(d => {
    const taxaAcerto = Math.round((d.acertos / d.total) * 100);
    return {
      disciplina: d.disciplina,
      totalRespondidas: d.total,
      acertos: d.acertos,
      erros: d.erros,
      taxaAcerto,
      taxaErro: 100 - taxaAcerto,
    };
  }).sort((a, b) => b.totalRespondidas - a.totalRespondidas);

  // Mapa de Dificuldades por Assunto
  const byTopic = {};
  attempts.forEach(a => {
    const disc = a.disciplina || "Geral";
    const assunto = a.assunto || "Geral";
    const key = `${disc}|||${assunto}`;

    if (!byTopic[key]) {
      byTopic[key] = {
        disciplina: disc,
        assunto,
        total: 0,
        acertos: 0,
        erros: 0,
        recentAttempts: [],
      };
    }
    byTopic[key].total += 1;
    if (a.acertou) byTopic[key].acertos += 1;
    else byTopic[key].erros += 1;
    byTopic[key].recentAttempts.push(a);
  });

  const mapaDificuldades = Object.values(byTopic).map(t => {
    const taxaAcerto = Math.round((t.acertos / t.total) * 100);
    const taxaErro = 100 - taxaAcerto;
    const classificacao = classifyTopicDifficulty(t.total, taxaErro, config);

    // Evolução recente no assunto (últimas 5 vs primeiras)
    let evolucaoRecente = "Estável";
    if (t.recentAttempts.length >= 6) {
      const ultimas3 = t.recentAttempts.slice(0, 3).filter(a => a.acertou).length / 3;
      const anteriores3 = t.recentAttempts.slice(3, 6).filter(a => a.acertou).length / 3;
      if (ultimas3 > anteriores3) evolucaoRecente = "Em melhora";
      else if (ultimas3 < anteriores3) evolucaoRecente = "Em queda";
    }

    let recomendacao = "Resolver mais questões para calibrar o diagnóstico.";
    if (classificacao.codigo === "alta") {
      recomendacao = "Revisar teoria base imediatamente e fazer bloco de 10 questões comentadas.";
    } else if (classificacao.codigo === "moderada") {
      recomendacao = "Fazer caderno de erros e resolver 5 questões deste assunto.";
    } else if (classificacao.codigo === "em_desenvolvimento") {
      recomendacao = "Conteúdo consolidado! Manter revisões espaçadas de 15 dias.";
    }

    return {
      disciplina: t.disciplina,
      assunto: t.assunto,
      totalRespondidas: t.total,
      taxaAcerto,
      taxaErro,
      classificacao,
      evolucaoRecente,
      recomendacao,
    };
  }).sort((a, b) => {
    // Ordenar: primeiro alta, depois moderada, depois outros, com maior total
    const peso = { alta: 3, moderada: 2, dados_insuficientes: 1, em_desenvolvimento: 0 };
    const diffPeso = peso[b.classificacao.codigo] - peso[a.classificacao.codigo];
    if (diffPeso !== 0) return diffPeso;
    return b.taxaErro - a.taxaErro;
  });

  // Série temporal dos últimos 14 dias (para gráfico de linha)
  const timelineDays = [];
  for (let i = 13; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const dateStr = d.toISOString().split("T")[0]; // YYYY-MM-DD
    const label = `${d.getDate()}/${d.getMonth() + 1}`;

    const dayAttempts = attempts.filter(a => (a.criadoEm || "").startsWith(dateStr));
    const daySummary = computeSummary(dayAttempts);

    timelineDays.push({
      date: dateStr,
      label,
      total: daySummary.total,
      acertos: daySummary.acertos,
      erros: daySummary.erros,
      taxaAcerto: daySummary.total > 0 ? daySummary.taxaAcerto : null,
    });
  }

  // Recomendações Automáticas Calculadas com Base em Regras
  const recomendacoesZuka = [];

  const topErro = mapaDificuldades.find(m => m.classificacao.codigo === "alta");
  if (topErro) {
    recomendacoesZuka.push({
      tipo: "alerta",
      icone: "fa-triangle-exclamation",
      cor: "red",
      titulo: `Atenção Crítica: ${topErro.disciplina}`,
      mensagem: `Você está errando mais questões de **${topErro.assunto}** (${topErro.taxaErro}% de erro em ${topErro.totalRespondidas} questões).`,
      acao: `Revisar ${topErro.assunto}`
    });
  }

  const topModerada = mapaDificuldades.find(m => m.classificacao.codigo === "moderada");
  if (topModerada) {
    recomendacoesZuka.push({
      tipo: "atencao",
      icone: "fa-circle-exclamation",
      cor: "orange",
      titulo: `Oportunidade de Ganho: ${topModerada.disciplina}`,
      mensagem: `Seu índice em **${topModerada.assunto}** está em ${topModerada.taxaAcerto}% de acertos. Com mais 5 a 10 questões você consolidará a matéria.`,
      acao: `Praticar ${topModerada.assunto}`
    });
  }

  if (evolucao7Dias.diferencaPP > 0 && evolucao7Dias.questoesPeriodo >= 5) {
    recomendacoesZuka.push({
      tipo: "positivo",
      icone: "fa-arrow-trend-up",
      cor: "green",
      titulo: "Evolução Positiva",
      mensagem: `Seu desempenho geral subiu **+${evolucao7Dias.diferencaPP} pontos percentuais** nos últimos 7 dias em relação à semana anterior!`,
      acao: "Ver histórico"
    });
  }

  const insuficientes = mapaDificuldades.filter(m => m.classificacao.codigo === "dados_insuficientes");
  if (insuficientes.length > 0) {
    recomendacoesZuka.push({
      tipo: "expansao",
      icone: "fa-compass",
      cor: "blue",
      titulo: "Expandir Cobertura do Edital",
      mensagem: `Você tem ${insuficientes.length} tópico(s) com menos de 5 questões resolvidas. Recomendamos resolver questões de novos tópicos para um diagnóstico completo.`,
      acao: "Abrir Banco de Questões"
    });
  }

  return {
    indicadoresGerais: {
      totalRespondidas: overall.total,
      totalAcertos: overall.acertos,
      totalErros: overall.erros,
      taxaAcertoGeral: overall.taxaAcerto,
      tempoMedioPorQuestao: overall.tempoMedio,
      evolucao7Dias,
      resumo30Dias: statsLast30,
    },
    desempenhoPorDisciplina: disciplinasRanking,
    mapaDificuldades,
    serieTemporal: timelineDays,
    recomendacoesZuka,
    configUtilizada: config,
    temDadosReais: overall.total > 0,
  };
}

module.exports = {
  DIFFICULTY_CONFIG,
  classifyTopicDifficulty,
  computeSummary,
  getStudentDashboardMetrics,
};
