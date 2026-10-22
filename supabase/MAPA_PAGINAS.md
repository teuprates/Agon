# 🗺️ Mapa de Páginas x Banco de Dados x Endpoints — AGON

Este documento mapeia cada uma das **16 páginas** em `public/*.html` para as tabelas, views, funções RPC e buckets de Storage que a sustentam, indicando os endpoints já existentes em `server.js` e os endpoints sugeridos para conectar os protótipos visuais restantes.

---

## 📋 Visão Geral por Página (16 Páginas)

| # | Página (`public/`) | Rota Express | Tabelas / Views / Buckets Utilizados | Endpoints Existentes (`server.js`) | Endpoints Sugeridos (Próxima Fase) | Status de Integração |
| :- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `home.html` | `GET /` | `concursos`, `depoimentos`, `planos_assinatura`, `vw_landing_estatisticas` | — | `GET /api/public/home-resumo` | 🟢 Pronto para ligar |
| 2 | `cadastro.html` | `GET /cadastro` | `usuarios`, `usuario_preferencias`, `aceites_termos` | `POST /api/cadastrar` | — | ✅ **Já integrado** |
| 3 | `login.html` | `GET /login` | `usuarios`, `sessoes_usuario`, `tentativas_login`, `tokens_redefinicao_senha` | `POST /api/login`<br>`POST /api/logout`<br>`GET /api/usuario` | `POST /api/auth/recuperar-senha`<br>`POST /api/auth/redefinir-senha` | ✅ **Já integrado** (login/sessão) |
| 4 | `index.html` | `GET /index`<br>`GET /dashboard` | `vw_dashboard_aluno_resumo`, `vw_evolucao_horas_estudo`, `vw_desempenho_disciplinas_aluno`, `aluno_concursos_acompanhados`, `atividades_recentes`, `notificacoes`, `ai_conversations` | `GET /api/usuario`<br>`GET /api/desempenho/estatisticas`<br>`POST /api/zuka/chat` | `GET /api/dashboard/resumo`<br>`GET /api/notificacoes`<br>`PATCH /api/notificacoes/:id/ler` | 🟡 Parcialmente integrado (usuário, desempenho, Zuka) / Pronto para ligar widgets |
| 5 | `questoes.html` | `GET /questoes` | `questoes`, `questao_alternativas`, `questao_comentarios`, `questao_favoritos`, `questao_anotacoes`, `cadernos_questoes`, `caderno_questoes_itens`, `question_attempts`, `student_topic_stats`, `fn_registrar_xp_aluno` | `POST /api/questoes/responder`<br>`GET /api/questoes/historico`<br>`GET /api/desempenho/estatisticas` | `GET /api/questoes` (filtros: disciplina, banca, ano, dificuldade)<br>`POST /api/questoes/:id/favoritar`<br>`POST /api/cadernos` | ✅ **Já integrado** (resolução, cálculo de estatísticas e dúvida Zuka IA) |
| 6 | `desempenho.html` | `GET /desempenho` | `question_attempts`, `student_topic_stats`, `study_recommendations`, `vw_desempenho_disciplinas_aluno`, `dias_estudo` | `GET /api/desempenho/estatisticas`<br>`GET /api/desempenho/recomendacoes`<br>`POST /api/desempenho/recalcular` | `PATCH /api/desempenho/recomendacoes/:id/concluir` | ✅ **Já integrado** |
| 7 | `ia-tutor.html` | `GET /ia-tutor` | `ai_conversations`, `ai_messages`, `student_topic_stats`, `study_recommendations`, `ai_generation_logs`, `ai_rate_limits` | `GET /api/zuka/status`<br>`GET /api/zuka/conversas`<br>`POST /api/zuka/conversas`<br>`GET /api/zuka/conversas/:id`<br>`DELETE /api/zuka/conversas/:id`<br>`POST /api/zuka/chat` | `POST /api/zuka/mensagens/:id/feedback` | ✅ **Já integrado** |
| 8 | `simulados.html` | `GET /simulados` | `simulados`, `simulado_questoes`, `simulado_tentativas`, `simulado_respostas`, `questoes`, `questao_alternativas`, `fn_calcular_resultado_simulado` | — | `GET /api/simulados`<br>`POST /api/simulados/gerar-ia`<br>`POST /api/simulados/:id/iniciar`<br>`POST /api/simulados/tentativas/:id/responder`<br>`POST /api/simulados/tentativas/:id/finalizar`<br>`GET /api/simulados/tentativas/:id/gabarito` | 🟢 Pronto para ligar |
| 9 | `aulas.html` | `GET /aulas` | `cursos`, `modulos`, `aulas`, `aula_anexos`, `aula_progresso`, `aula_anotacoes`, `aula_perguntas`, `aula_respostas`, `certificados`, bucket `aulas-anexos` | — | `GET /api/cursos/:slug`<br>`POST /api/aulas/:id/progresso`<br>`GET /api/aulas/:id/anotacoes`<br>`POST /api/aulas/:id/anotacoes`<br>`POST /api/aulas/:id/perguntas` | 🟢 Pronto para ligar |
| 10 | `estudos.html` | `GET /estudos` | `cursos`, `aulas`, `aula_progresso`, `disciplinas`, `revisoes_espacadas_sm2`, `caderno_erros`, `flashcards`, `fn_calcular_revisao_sm2` | — | `GET /api/estudos/visao-geral`<br>`GET /api/estudos/revisoes-sm2`<br>`POST /api/estudos/revisoes-sm2/:id/avaliar`<br>`GET /api/estudos/caderno-erros`<br>`GET /api/estudos/flashcards` | 🟢 Pronto para ligar |
| 11 | `planos-estudo.html` | `GET /planos-estudo` | `planos_estudo`, `cronograma_tarefas`, `edital_topicos`, `aluno_edital_progresso`, `revisoes_espacadas_sm2`, `concursos` | — | `GET /api/planos-estudo/atual`<br>`PUT /api/planos-estudo/configurar`<br>`PATCH /api/planos-estudo/tarefas/:id/toggle`<br>`GET /api/planos-estudo/edital-verticalizado` | 🟢 Pronto para ligar |
| 12 | `materiais.html` | `GET /materiais` | `materiais`, `material_interacoes`, `disciplinas`, bucket `materiais` | — | `GET /api/materiais` (filtros: categoria, disciplina, busca)<br>`POST /api/materiais/:id/favoritar`<br>`POST /api/materiais/:id/download`<br>`PATCH /api/materiais/:id/progresso-leitura` | 🟢 Pronto para ligar |
| 13 | `comunidade.html` | `GET /comunidade` | `comunidade_posts`, `comunidade_post_hashtags`, `comunidade_comentarios`, `comunidade_curtidas`, `comunidade_favoritos`, `comunidade_enquete_opcoes`, `comunidade_enquete_votos`, `comunidade_salas_estudo`, `comunidade_sala_presenca`, `comunidade_denuncias`, `vw_comunidade_topicos_alta`, `vw_ranking_temporada`, bucket `comunidade-anexos` | — | `GET /api/comunidade/posts`<br>`POST /api/comunidade/posts`<br>`POST /api/comunidade/posts/:id/curtir`<br>`POST /api/comunidade/posts/:id/favoritar`<br>`POST /api/comunidade/posts/:id/comentarios`<br>`POST /api/comunidade/enquetes/:opcaoId/votar`<br>`POST /api/comunidade/salas/:id/entrar` | 🟢 Pronto para ligar |
| 14 | `conquistas.html` | `GET /conquistas` | `niveis`, `temporadas`, `conquistas`, `aluno_conquistas`, `xp_ledger`, `dias_estudo`, `vw_ranking_temporada`, `fn_avaliar_conquistas_aluno` | — | `GET /api/conquistas/resumo`<br>`GET /api/conquistas/ranking`<br>`POST /api/conquistas/reavaliar` | 🟢 Pronto para ligar |
| 15 | `configuracoes.html` | `GET /configuracoes` | `usuarios`, `usuario_preferencias`, `planos_assinatura`, `assinaturas`, `faturas`, `sessoes_usuario`, bucket `avatars` | `GET /api/usuario` | `PUT /api/configuracoes/perfil`<br>`POST /api/configuracoes/avatar`<br>`PUT /api/configuracoes/preferencias`<br>`PUT /api/configuracoes/senha`<br>`GET /api/configuracoes/assinatura-faturas`<br>`DELETE /api/configuracoes/sessoes/:id`<br>`DELETE /api/configuracoes/conta` | 🟢 Pronto para ligar |
| 16 | `em-breve.html` | `GET /em-breve` | `roadmap_fases`, `roadmap_modulos`, `lista_espera_modulos`, `sugestoes_produto` | — | `GET /api/roadmap/:moduloSlug`<br>`POST /api/roadmap/lista-espera`<br>`POST /api/roadmap/sugestoes` | 🟢 Pronto para ligar |
| — | `setores.html` | *(Redireciona p/ `/index`)* | Redirecionamento legado de compatibilidade (`meta http-equiv="refresh" url=/index`) | `GET /setores` | — | ✅ Redirecionamento legado |

---

## 🔎 Componentes Transversais (Presentes em Todas as Páginas Internas)

Além dos elementos específicos de cada página, todas as páginas autenticadas compartilham 3 componentes globais na Topbar e no Modal de Perfil (`public/js/script.js`), todos cobertos pelo banco:

1. **Busca Global na Topbar (`input.search-input`):**
   - Pode consultar de forma unificada `questoes` (`codigo`, `enunciado`, `assunto_nome`), `aulas` (`titulo`, `resumo_teorico`), `materiais` (`titulo`, `descricao`) e `comunidade_posts` (`titulo`, `conteudo`).
2. **Dropdown de Notificações (`#notif-btn` / `#notif-dropdown`):**
   - Alimentado diretamente pela tabela `public.notificacoes` filtrada por `user_id` e ordenada por `lida ASC, criado_em DESC`.
3. **Modal Rápido "Meu Perfil" (`#profile-modal` — Abas Dados, Conquistas e Configurações):**
   - **Aba Dados:** `public.usuarios` + `public.assinaturas`
   - **Aba Conquistas:** `public.vw_dashboard_aluno_resumo` + `public.aluno_conquistas` + `public.conquistas`
   - **Aba Configurações:** `public.usuario_preferencias` (`tema`, `notif_resumo_semanal_email`, `notif_lembrete_diario`, `horario_lembrete_diario`)
