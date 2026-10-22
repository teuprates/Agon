const fs = require('fs');

let html = fs.readFileSync('public/desempenho.html', 'utf-8');

// Atualiza o título da página
html = html.replace(
  '<h1 class="text-2xl sm:text-3xl font-bold tracking-tight" style="color: var(--text-primary);">Desempenho</h1>',
  '<h1 class="text-2xl sm:text-3xl font-bold tracking-tight" style="color: var(--text-primary);">Desempenho com a Zuka IA</h1>'
);

// Adiciona IDs aos cards de indicadores gerais
html = html.replace(
  '<div class="text-2xl font-bold tracking-tight" style="color: var(--text-primary);">82%</div>',
  '<div id="stat-taxa-geral" class="text-2xl font-bold tracking-tight" style="color: var(--text-primary);">0%</div>'
);
html = html.replace(
  '<div class="text-2xl font-bold tracking-tight" style="color: var(--text-primary);">1.248</div>',
  '<div id="stat-total-questoes" class="text-2xl font-bold tracking-tight" style="color: var(--text-primary);">0</div>'
);
html = html.replace(
  '<div class="text-2xl font-bold tracking-tight" style="color: var(--text-primary);">75.0%</div>',
  '<div id="stat-total-acertos" class="text-2xl font-bold tracking-tight" style="color: var(--text-green);">0</div>'
);
html = html.replace(
  '<div class="text-2xl font-bold tracking-tight" style="color: var(--text-primary);">Top 12%</div>',
  '<div id="stat-tempo-medio" class="text-2xl font-bold tracking-tight" style="color: var(--text-primary);">0s</div>'
);

// Atualiza legendas dos 4 cards de topo
html = html.replace(
  '<span class="text-sm font-semibold" style="color: var(--text-secondary);">Média em Simulados</span>',
  '<span class="text-sm font-semibold" style="color: var(--text-secondary);">Total de Acertos</span>'
);
html = html.replace(
  '<span class="text-sm font-semibold" style="color: var(--text-secondary);">Melhor Ranking</span>',
  '<span class="text-sm font-semibold" style="color: var(--text-secondary);">Tempo Médio / Questão</span>'
);

// Inserção da seção Recomendações da Zuka IA e Mapa de Dificuldades
const secaoZukaIA = `
        <!-- SEÇÃO: RECOMENDAÇÕES DA ZUKA IA -->
        <div id="zuka-recs-section" class="card p-6 space-y-4">
          <div class="flex items-center justify-between flex-wrap gap-3 pb-3 border-b" style="border-color: var(--border-light);">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-xl flex items-center justify-center" style="background: var(--color-blue-light); color: var(--color-blue);">
                <i class="fa-solid fa-robot text-lg"></i>
              </div>
              <div>
                <h3 class="card-title text-lg font-bold flex items-center gap-2">
                  <span>Diagnóstico Inteligente da Zuka IA</span>
                  <span class="badge badge-green text-xs font-semibold">Baseado em Dados Reais</span>
                </h3>
                <p class="card-subtitle text-xs sm:text-sm mt-0.5">Análise automática das suas maiores dificuldades e prioridades de estudo</p>
              </div>
            </div>
            <a href="ia-tutor.html" class="btn-primary text-xs py-2 px-4 flex items-center gap-2 shadow-sm">
              <i class="fa-solid fa-message text-xs"></i>
              <span>Conversar com a Zuka IA</span>
            </a>
          </div>

          <!-- Cards dinâmicos de recomendações -->
          <div id="zuka-recs-container" class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="p-4 rounded-xl border flex items-center justify-center text-xs" style="background-color: var(--bg-input); border-color: var(--border-default); color: var(--text-muted);">
              Carregando diagnóstico da Zuka IA...
            </div>
          </div>
        </div>

        <!-- SEÇÃO: MAPA DE DIFICULDADES POR ASSUNTO -->
        <div class="card p-6">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
            <div>
              <h3 class="card-title text-lg font-bold flex items-center gap-2">
                <i class="fa-solid fa-map-location-dot" style="color: var(--color-blue);"></i>
                <span>Mapa de Dificuldades por Assunto</span>
              </h3>
              <p class="card-subtitle text-xs sm:text-sm mt-0.5">Classificação transparente: Alta (erro &ge; 60%), Moderada (35-59%), Bom Desempenho (&lt; 35%) e Dados Insuficientes (&lt; 5 questões)</p>
            </div>
            <div class="flex items-center gap-2">
              <a href="questoes.html" class="btn-secondary text-xs py-1.5 px-3 flex items-center gap-1.5">
                <i class="fa-solid fa-circle-question text-xs"></i> Praticar Questões
              </a>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="data-table w-full text-xs">
              <thead>
                <tr class="text-left border-b" style="border-color: var(--border-light);">
                  <th class="py-3 px-4">Disciplina / Assunto</th>
                  <th class="py-3 px-4 text-center">Questões</th>
                  <th class="py-3 px-4 text-center">Taxa Acerto / Erro</th>
                  <th class="py-3 px-4 text-center">Classificação</th>
                  <th class="py-3 px-4 text-center">Evolução</th>
                  <th class="py-3 px-4 text-left">Recomendação da Zuka IA</th>
                </tr>
              </thead>
              <tbody id="mapa-dificuldades-tbody">
                <tr>
                  <td colspan="6" class="py-6 text-center text-xs" style="color: var(--text-muted);">
                    Nenhuma questão respondida ainda. Inicie a resolução no Banco de Questões para alimentar seu mapa de dificuldades.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
`;

// Insere antes do histórico de simulados
html = html.replace(
  '<!-- 3. BOTTOM CARD: HISTÓRICO DE SIMULADOS -->',
  secaoZukaIA + '\n        <!-- 3. BOTTOM CARD: HISTÓRICO DE SIMULADOS -->'
);

// Atualiza o script de renderização com a chamada à API real
const scriptPlaceholder = `  <!-- Chart.js Initialization for Desempenho -->`;
const dynamicScript = `  <!-- Chart.js & Real Performance Integration -->
  <script>
    let lineChartDesempenhoInstance = null;
    let radarChartInstance = null;

    async function loadRealPerformanceData() {
      try {
        const res = await fetch('/api/desempenho/estatisticas');
        const data = await res.json();
        const ig = data.indicadoresGerais;

        // Atualiza Cards de Topo
        const elTaxa = document.getElementById('stat-taxa-geral');
        const elTotal = document.getElementById('stat-total-questoes');
        const elAcertos = document.getElementById('stat-total-acertos');
        const elTempo = document.getElementById('stat-tempo-medio');

        if (elTaxa) elTaxa.textContent = (ig.totalRespondidas > 0 ? ig.taxaAcertoGeral : 0) + '%';
        if (elTotal) elTotal.textContent = ig.totalRespondidas;
        if (elAcertos) elAcertos.textContent = ig.totalAcertos + ' acertos (' + ig.totalErros + ' erros)';
        if (elTempo) elTempo.textContent = ig.tempoMedioPorQuestao > 0 ? (ig.tempoMedioPorQuestao + 's') : '--';

        // Atualiza Recomendações Zuka IA
        const recsContainer = document.getElementById('zuka-recs-container');
        if (recsContainer) {
          recsContainer.innerHTML = '';
          const recs = data.recomendacoesZuka || [];
          if (recs.length === 0) {
            recsContainer.innerHTML = \`
              <div class="col-span-3 p-4 rounded-xl border text-center text-xs" style="background-color: var(--bg-input); border-color: var(--border-default); color: var(--text-muted);">
                <i class="fa-solid fa-sparkles mr-1.5 text-blue-500"></i>
                Resolva pelo menos 5 questões no <a href="questoes.html" class="underline font-semibold text-blue-600">Banco de Questões</a> para que a Zuka IA gere recomendações personalizadas.
              </div>
            \`;
          } else {
            recs.forEach(r => {
              const card = document.createElement('div');
              card.className = 'p-4 rounded-xl border flex flex-col justify-between transition hover:shadow-sm';
              card.style.backgroundColor = 'var(--bg-input)';
              card.style.borderColor = 'var(--border-default)';
              card.innerHTML = \`
                <div>
                  <div class="flex items-center gap-2 mb-2">
                    <i class="fa-solid \${r.icone} text-sm" style="color: var(--color-\${r.cor});"></i>
                    <h4 class="font-bold text-xs" style="color: var(--text-primary);">\${r.titulo}</h4>
                  </div>
                  <p class="text-xs leading-relaxed" style="color: var(--text-secondary);">\${r.mensagem.replace(/\\*\\*(.*?)\\*\\*/g, '<strong>$1</strong>')}</p>
                </div>
                <div class="mt-3 pt-2 border-t" style="border-color: var(--border-light);">
                  <a href="questoes.html" class="text-[11px] font-semibold flex items-center justify-between" style="color: var(--color-blue);">
                    <span>\${r.acao}</span>
                    <i class="fa-solid fa-arrow-right text-[10px]"></i>
                  </a>
                </div>
              \`;
              recsContainer.appendChild(card);
            });
          }
        }

        // Atualiza Tabela de Mapa de Dificuldades
        const tbody = document.getElementById('mapa-dificuldades-tbody');
        if (tbody) {
          tbody.innerHTML = '';
          const mapa = data.mapaDificuldades || [];
          if (mapa.length === 0) {
            tbody.innerHTML = \`
              <tr>
                <td colspan="6" class="py-6 text-center text-xs" style="color: var(--text-muted);">
                  Nenhuma questão respondida ainda. Inicie no <a href="questoes.html" class="underline font-semibold text-blue-600">Banco de Questões</a>.
                </td>
              </tr>
            \`;
          } else {
            mapa.forEach(item => {
              const tr = document.createElement('tr');
              tr.className = 'border-b transition hover:bg-slate-50 dark:hover:bg-slate-900/20';
              tr.style.borderColor = 'var(--border-light)';

              const corBadge = {
                alta: 'badge-red',
                moderada: 'badge-orange',
                em_desenvolvimento: 'badge-green',
                dados_insuficientes: 'badge-gray'
              }[item.classificacao.codigo] || 'badge-gray';

              tr.innerHTML = \`
                <td class="py-3 px-4">
                  <span class="font-bold block" style="color: var(--text-primary);">\${item.disciplina}</span>
                  <span class="text-[11px]" style="color: var(--text-muted);">\${item.assunto}</span>
                </td>
                <td class="py-3 px-4 text-center font-semibold" style="color: var(--text-primary);">
                  \${item.totalRespondidas}
                </td>
                <td class="py-3 px-4 text-center">
                  <span class="font-bold text-emerald-600 dark:text-emerald-400">\${item.taxaAcerto}%</span> / 
                  <span class="font-bold text-rose-500">\${item.taxaErro}%</span>
                </td>
                <td class="py-3 px-4 text-center">
                  <span class="badge \${corBadge} text-[11px] font-semibold">\${item.classificacao.label}</span>
                </td>
                <td class="py-3 px-4 text-center text-[11px]" style="color: var(--text-secondary);">
                  \${item.evolucaoRecente}
                </td>
                <td class="py-3 px-4 text-left text-[11px]" style="color: var(--text-secondary);">
                  \${item.recomendacao}
                </td>
              \`;
              tbody.appendChild(tr);
            });
          }
        }

        // Renderiza Gráficos com Dados Reais
        renderCharts(data);
      } catch (err) {
        console.error('Erro ao buscar dados de desempenho:', err);
      }
    }

    function renderCharts(apiData) {
      if (typeof getChartColors !== 'function') return;
      const colors = getChartColors();
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';

      // 1. Line Chart: Série Temporal Real (últimos 14 dias)
      const ctxLine = document.getElementById('lineChartDesempenho');
      if (ctxLine && apiData && apiData.serieTemporal) {
        if (lineChartDesempenhoInstance) lineChartDesempenhoInstance.destroy();

        const labels = apiData.serieTemporal.map(d => d.label);
        const values = apiData.serieTemporal.map(d => d.taxaAcerto !== null ? d.taxaAcerto : null);

        lineChartDesempenhoInstance = new Chart(ctxLine, {
          type: 'line',
          data: {
            labels,
            datasets: [{
              label: 'Taxa de Acertos (%)',
              data: values,
              borderColor: colors.blue,
              backgroundColor: colors.bgBlue,
              borderWidth: 2.5,
              fill: true,
              tension: 0.35,
              spanGaps: true,
              pointBackgroundColor: colors.pointBg,
              pointBorderColor: colors.blue,
              pointBorderWidth: 2,
              pointRadius: 4,
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { display: false },
              tooltip: {
                callbacks: {
                  label: ctx => ctx.raw !== null ? \` \${ctx.raw}% de acertos\` : ' Sem atividades'
                }
              }
            },
            scales: {
              x: { grid: { color: colors.grid }, ticks: { color: colors.text } },
              y: { min: 0, max: 100, grid: { color: colors.grid }, ticks: { color: colors.text, callback: v => v + '%' } }
            }
          }
        });
      }

      // 2. Bar Chart: Comparativo por Disciplina Real
      const ctxRadar = document.getElementById('radarChart');
      if (ctxRadar && apiData && apiData.desempenhoPorDisciplina) {
        if (radarChartInstance) radarChartInstance.destroy();

        const discData = apiData.desempenhoPorDisciplina;
        const labels = discData.length > 0 ? discData.map(d => d.disciplina) : ['Sem dados'];
        const acertosData = discData.length > 0 ? discData.map(d => d.taxaAcerto) : [0];
        const errosData = discData.length > 0 ? discData.map(d => d.taxaErro) : [0];

        radarChartInstance = new Chart(ctxRadar, {
          type: 'bar',
          data: {
            labels,
            datasets: [
              {
                label: '% Acertos',
                data: acertosData,
                backgroundColor: 'rgba(16, 185, 129, 0.85)',
                borderRadius: 6,
              },
              {
                label: '% Erros',
                data: errosData,
                backgroundColor: 'rgba(239, 68, 68, 0.75)',
                borderRadius: 6,
              }
            ]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { position: 'top', labels: { color: colors.text } },
              tooltip: {
                callbacks: {
                  label: ctx => \` \${ctx.dataset.label}: \${ctx.raw}%\`
                }
              }
            },
            scales: {
              x: { grid: { display: false }, ticks: { color: colors.text } },
              y: { min: 0, max: 100, grid: { color: colors.grid }, ticks: { color: colors.text, callback: v => v + '%' } }
            }
          }
        });
      }
    }

    document.addEventListener('DOMContentLoaded', loadRealPerformanceData);

    const themeObserver = new MutationObserver(() => loadRealPerformanceData());
    themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  </script>
`;

html = html.replace(scriptPlaceholder, dynamicScript);

fs.writeFileSync('public/desempenho.html', html, 'utf-8');
console.log('Successfully updated public/desempenho.html!');
