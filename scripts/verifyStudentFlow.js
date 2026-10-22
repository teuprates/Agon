const main = async () => {
  const authRes = await fetch('http://localhost:3500/api/check-auth');
  const cookie = authRes.headers.get('set-cookie').split(';')[0];
  const headers = { 'Content-Type': 'application/json', 'Cookie': cookie };

  // 1. Answer 6 questions in Direito Constitucional (4 wrong, 2 right => 66.7% error)
  for (let i = 1; i <= 6; i++) {
    const isRight = i <= 2;
    await fetch('http://localhost:3500/api/questoes/responder', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        questionId: 'Q_DC_' + i,
        disciplina: 'Direito Constitucional',
        assunto: 'Princípios Fundamentais',
        respostaSelecionada: isRight ? 'B' : 'A',
        respostaCorreta: 'B',
        acertou: isRight,
        tempoGastoSegundos: 30 + i * 2,
        banca: 'Cebraspe',
        ano: '2024'
      })
    });
  }

  // 2. Answer 5 questions in Português (5 right => 0% error)
  for (let i = 1; i <= 5; i++) {
    await fetch('http://localhost:3500/api/questoes/responder', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        questionId: 'Q_PT_' + i,
        disciplina: 'Língua Portuguesa',
        assunto: 'Emprego da Crase',
        respostaSelecionada: 'B',
        respostaCorreta: 'B',
        acertou: true,
        tempoGastoSegundos: 20 + i * 2,
        banca: 'FGV',
        ano: '2023'
      })
    });
  }

  // 3. Fetch Dashboard Stats
  const res = await fetch('http://localhost:3500/api/desempenho/estatisticas', { headers });
  const data = await res.json();
  console.log('=== VERIFICAÇÃO DO DASHBOARD REAL ===');
  console.log('Total Respondidas:', data.indicadoresGerais.totalRespondidas);
  console.log('Total Acertos:', data.indicadoresGerais.totalAcertos);
  console.log('Total Erros:', data.indicadoresGerais.totalErros);
  console.log('Taxa Geral:', data.indicadoresGerais.taxaAcertoGeral + '%');
  console.log('Tempo Médio:', data.indicadoresGerais.tempoMedioPorQuestao + 's');
  console.log('Disciplinas:', data.desempenhoPorDisciplina);
  console.log('Mapa de Dificuldades:');
  data.mapaDificuldades.forEach(m => {
    console.log(`- ${m.disciplina} (${m.assunto}): ${m.totalRespondidas} resp, ${m.taxaAcerto}% acerto, ${m.taxaErro}% erro => [${m.classificacao.codigo.toUpperCase()}] ${m.classificacao.label}`);
    console.log(`  Recomendação: ${m.recomendacao}`);
  });
  console.log('Recomendações da Zuka IA:');
  data.recomendacoesZuka.forEach(r => console.log(`• [${r.tipo}] ${r.titulo}: ${r.mensagem}`));
};

main();
