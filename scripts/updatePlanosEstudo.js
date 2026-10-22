const fs = require('fs');
let html = fs.readFileSync('public/planos-estudo.html', 'utf-8');

// Atualiza o card de Sugestão da IA
const oldCard = `            <div class="card p-5 space-y-3">
              <div class="flex items-center gap-2">
                <i class="fa-solid fa-wand-magic-sparkles text-amber-500"></i>
                <h4 class="font-bold text-sm" style="color: var(--text-primary);">Sugestão da IA Agon</h4>
              </div>
              <p class="text-xs leading-relaxed" style="color: var(--text-secondary);">
                Você acertou <strong class="text-emerald-600">92%</strong> em Direito Constitucional esta semana. Recomendamos transferir <strong>1h</strong> dessa matéria para <strong>Informática</strong>, onde sua média está em 68%.
              </p>
              <button class="btn-primary w-full text-xs py-2 justify-center">Otimizar Cronograma Automaticamente</button>
            </div>`;

const newCard = `            <div class="card p-5 space-y-3" id="zuka-study-plan-card">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-7 h-7 rounded-lg flex items-center justify-center text-xs" style="background: var(--color-blue-light); color: var(--color-blue);">
                    <i class="fa-solid fa-robot"></i>
                  </div>
                  <h4 class="font-bold text-sm" style="color: var(--text-primary);">Plano Inteligente Zuka IA</h4>
                </div>
                <span id="zuka-plan-badge" class="badge badge-green text-[10px]">Real</span>
              </div>
              <div id="zuka-plan-content" class="text-xs leading-relaxed space-y-2" style="color: var(--text-secondary);">
                <p>Analisando seus dados reais de desempenho para priorizar os temas mais cobrados e com maior taxa de erro...</p>
              </div>
              <button id="btn-otimizar-zuka" class="btn-primary w-full text-xs py-2 justify-center flex items-center gap-1.5 shadow-sm">
                <i class="fa-solid fa-wand-magic-sparkles text-xs"></i>
                <span>Otimizar com a Zuka IA</span>
              </button>
            </div>`;

html = html.replace(oldCard, newCard);

// Adiciona script para carregar as recomendações da Zuka IA
const oldScriptEnd = `    });
  </script>`;

const newScriptAdd = `      // ─── Integração Real da Zuka IA com o Plano de Estudos ───
      async function loadZukaStudyPlan() {
        const contentBox = document.getElementById('zuka-plan-content');
        if (!contentBox) return;

        try {
          const res = await fetch('/api/planos-estudo/recomendacoes');
          const data = await res.json();

          if (!data.temDadosReais) {
            contentBox.innerHTML = '<p>Você ainda não possui tentativas suficientes registradas no banco. Resolva questões em <a href="questoes.html" class="underline font-semibold text-blue-600">Questões</a> para gerar seu plano adaptativo!</p>';
            return;
          }

          const recs = data.recomendacoesCalculadas || [];
          if (recs.length > 0) {
            let htmlList = '<ul class="space-y-1.5">';
            recs.slice(0, 3).forEach(r => {
              htmlList += '<li class="flex items-start gap-1.5"><i class="fa-solid fa-arrow-right text-[10px] mt-1 text-blue-500"></i> <span>' + r.mensagem.replace(/\\*\\*(.*?)\\*\\*/g, '<strong>$1</strong>') + '</span></li>';
            });
            htmlList += '</ul>';
            contentBox.innerHTML = htmlList;
          }
        } catch (e) {
          console.warn('Aviso ao carregar recomendações de estudo:', e);
        }
      }
      loadZukaStudyPlan();

      const btnOtimizar = document.getElementById('btn-otimizar-zuka');
      if (btnOtimizar) {
        btnOtimizar.addEventListener('click', async () => {
          const contentBox = document.getElementById('zuka-plan-content');
          btnOtimizar.disabled = true;
          btnOtimizar.innerHTML = '<i class="fa-solid fa-spinner fa-spin text-xs"></i> Otimizando...';

          try {
            const concurso = document.getElementById('modal-exam-select')?.value || 'Polícia Federal (Agente)';
            const horas = document.getElementById('modal-hours-input')?.value || 4;

            const res = await fetch('/api/planos-estudo/gerar-ia', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ concursoAlvo: concurso, horasSemanais: horas * 5 })
            });
            const data = await res.json();

            if (data.recomendacaoTexto) {
              contentBox.innerHTML = '<div class="p-2.5 rounded-lg bg-blue-50 dark:bg-blue-950/30 text-blue-900 dark:text-blue-200 text-xs">' + data.recomendacaoTexto.replace(/\\n/g, '<br/>').replace(/\\*\\*(.*?)\\*\\*/g, '<strong>$1</strong>') + '</div>';
            }
          } catch (err) {
            alert('Falha ao conectar com o serviço da Zuka IA.');
          } finally {
            btnOtimizar.disabled = false;
            btnOtimizar.innerHTML = '<i class="fa-solid fa-wand-magic-sparkles text-xs"></i> Otimizar com a Zuka IA';
          }
        });
      }
    });
  </script>`;

html = html.replace(oldScriptEnd, newScriptAdd);

fs.writeFileSync('public/planos-estudo.html', html, 'utf-8');
console.log('Successfully updated public/planos-estudo.html!');
