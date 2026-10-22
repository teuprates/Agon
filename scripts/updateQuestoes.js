const fs = require('fs');
let html = fs.readFileSync('public/questoes.html', 'utf-8');

// 1. Performance card updates
html = html.replace(
  '<div class="text-3xl font-extrabold tracking-tight" style="color: var(--color-blue);">1.248</div>',
  '<div id="perf-total-count" class="text-3xl font-extrabold tracking-tight" style="color: var(--color-blue);">0</div>'
);
html = html.replace(
  '<span class="font-bold" style="color: var(--color-green);">78% de acerto</span>',
  '<span id="perf-taxa-acerto" class="font-bold" style="color: var(--color-green);">0% de acerto</span>'
);
html = html.replace(
  '<div class="progress-fill-green h-2.5" style="width: 78%; background-color: var(--color-green);"></div>',
  '<div id="perf-progress-fill" class="progress-fill-green h-2.5" style="width: 0%; background-color: var(--color-green);"></div>'
);
html = html.replace(
  '<p class="text-sm font-bold" style="color: var(--color-green);"><i class="fa-solid fa-check text-xs mr-1"></i>973</p>',
  '<p id="perf-acertos-count" class="text-sm font-bold" style="color: var(--color-green);"><i class="fa-solid fa-check text-xs mr-1"></i>0</p>'
);
html = html.replace(
  '<p class="text-sm font-bold" style="color: var(--color-red);"><i class="fa-solid fa-xmark text-xs mr-1"></i>275</p>',
  '<p id="perf-erros-count" class="text-sm font-bold" style="color: var(--color-red);"><i class="fa-solid fa-xmark text-xs mr-1"></i>0</p>'
);

// 2. Add data-assunto
html = html.replace('id="question-1" data-disciplina="direito-constitucional"', 'id="question-1" data-disciplina="Direito Constitucional" data-assunto="Princípios Fundamentais"');
html = html.replace('id="question-2" data-disciplina="portugues"', 'id="question-2" data-disciplina="Língua Portuguesa" data-assunto="Emprego da Crase"');
html = html.replace('id="question-3" data-disciplina="raciocinio-logico"', 'id="question-3" data-disciplina="Raciocínio Lógico" data-assunto="Equivalências e Negação Lógica"');

// 3. Add 'Explicar com Zuka IA' button to action bars
const zukaBtn = (qid) => ' <button type="button" class="btn-secondary btn-zuka-duvida text-xs py-2 px-3 flex items-center gap-1.5 font-semibold text-blue-600 dark:text-blue-400" data-target="' + qid + '"><i class="fa-solid fa-robot text-xs"></i> Explicar com Zuka IA</button>';

html = html.replace(
  /(data-target="comment-1"[^>]*>[\s\S]*?Comentário do Professor[\s\S]*?<\/button>)/,
  '$1' + zukaBtn('question-1')
);
html = html.replace(
  /(data-target="comment-2"[^>]*>[\s\S]*?Comentário do Professor[\s\S]*?<\/button>)/,
  '$1' + zukaBtn('question-2')
);
html = html.replace(
  /(data-target="comment-3"[^>]*>[\s\S]*?Comentário da Professora[\s\S]*?<\/button>)/,
  '$1' + zukaBtn('question-3')
);

// 4. Update JavaScript to record answers and handle Zuka AI
const oldScript = `      // ─── Answer Checking (Responder) ──────────────────────────`;
const newScript = `      // ─── Atualização em Tempo Real do Card de Desempenho ───
      async function refreshPerformanceWidget() {
        try {
          const res = await fetch('/api/desempenho/estatisticas');
          const data = await res.json();
          if (data.indicadoresGerais) {
            const ig = data.indicadoresGerais;
            const elTotal = document.getElementById('perf-total-count');
            const elTaxa = document.getElementById('perf-taxa-acerto');
            const elFill = document.getElementById('perf-progress-fill');
            const elAcertos = document.getElementById('perf-acertos-count');
            const elErros = document.getElementById('perf-erros-count');

            if (elTotal) elTotal.textContent = ig.totalRespondidas;
            if (elTaxa) elTaxa.textContent = (ig.totalRespondidas > 0 ? ig.taxaAcertoGeral : 0) + '% de acerto';
            if (elFill) elFill.style.width = (ig.totalRespondidas > 0 ? ig.taxaAcertoGeral : 0) + '%';
            if (elAcertos) elAcertos.innerHTML = '<i class="fa-solid fa-check text-xs mr-1"></i>' + ig.totalAcertos;
            if (elErros) elErros.innerHTML = '<i class="fa-solid fa-xmark text-xs mr-1"></i>' + ig.totalErros;
          }
        } catch (err) {
          console.warn('Aviso ao sincronizar estatísticas:', err);
        }
      }
      refreshPerformanceWidget();

      // ─── Botão: Explicar com Zuka IA ────────────────────────
      document.querySelectorAll('.btn-zuka-duvida').forEach(btn => {
        btn.addEventListener('click', function () {
          const cardId = this.dataset.target;
          const card = document.getElementById(cardId);
          if (!card) return;

          const qid = card.querySelector('.font-mono')?.textContent.trim() || cardId;
          const disciplina = card.dataset.disciplina || 'Concursos';
          const assunto = card.dataset.assunto || 'Geral';
          const banca = card.dataset.banca || '';
          const ano = card.dataset.ano || '';
          const enunciado = card.querySelector('.space-y-3 p')?.textContent.trim() || '';

          const alternativas = Array.from(card.querySelectorAll('.option-item')).map(opt => ({
            letra: opt.querySelector('.option-letter')?.textContent.trim() || '',
            texto: opt.querySelector('.text-sm')?.textContent.trim() || '',
          }));

          const correctOpt = card.querySelector('.option-item[data-correct="true"]');
          const gabaritoOficial = correctOpt?.querySelector('.option-letter')?.textContent.trim() || '';

          const commentBoxId = cardId.replace('question-', 'comment-');
          const comentarioOficial = document.getElementById(commentBoxId)?.querySelector('p')?.textContent.trim() || '';

          const selectedOption = card.querySelector('input[type="radio"]:checked');
          const respostaSelecionada = selectedOption?.value || '';

          const questionContext = {
            questionId: qid,
            disciplina,
            assunto,
            banca,
            ano,
            enunciado,
            alternativas,
            gabaritoOficial,
            comentarioOficial,
            respostaSelecionada
          };

          const encoded = encodeURIComponent(JSON.stringify(questionContext));
          window.location.href = 'ia-tutor.html?qctx=' + encoded;
        });
      });

      // ─── Answer Checking (Responder) ──────────────────────────`;

html = html.replace(oldScript, newScript);

// Hook into inside btn-responder click to make the backend call
const oldInsideResponder = `          // Disable radios
          card.querySelectorAll('input[type="radio"]').forEach(r => r.disabled = true);`;

const newInsideResponder = `          // Registra a tentativa real no backend Agon
          const qid = card.querySelector('.font-mono')?.textContent.trim() || cardId;
          const disciplina = card.dataset.disciplina || 'Geral';
          const assunto = card.dataset.assunto || 'Geral';
          const banca = card.dataset.banca || '';
          const ano = card.dataset.ano || '';
          const gabaritoLetra = card.querySelector('.option-item[data-correct="true"] .option-letter')?.textContent.trim() || '';

          fetch('/api/questoes/responder', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              questionId: qid,
              disciplina,
              assunto,
              respostaSelecionada: selectedOption.value,
              respostaCorreta: gabaritoLetra,
              acertou: isCorrect,
              tempoGastoSegundos: 35,
              banca,
              ano
            })
          })
          .then(res => res.json())
          .then(() => refreshPerformanceWidget())
          .catch(e => console.warn('Erro ao salvar resposta no banco:', e));

          // Disable radios
          card.querySelectorAll('input[type="radio"]').forEach(r => r.disabled = true);`;

html = html.replace(oldInsideResponder, newInsideResponder);

fs.writeFileSync('public/questoes.html', html, 'utf-8');
console.log('Successfully updated public/questoes.html!');
