# 🚀 Guia de Integração e Migrações Supabase — AGON

Este diretório contém a arquitetura completa de banco de dados PostgreSQL + Supabase da plataforma **AGON**, incluindo **15 migracoes sequenciais idempotentes**, **seeds de catálogo e demonstração**, **views analíticas**, **funções RPC**, **políticas RLS** e **buckets de Storage**, cobrindo todas as **16 páginas** de `public/`.

---

## 📂 Documentação Técnica do Banco

- **[`SCHEMA.md`](./SCHEMA.md)**: Diagrama Entidade-Relacionamento (Mermaid ER), estratégia de Identidade/RLS, ambiguidades resolvidas e dicionário completo das **75 tabelas**, **6 views**, **5 funções RPC** e **4 buckets de Storage**.
- **[`MAPA_PAGINAS.md`](./MAPA_PAGINAS.md)**: Mapeamento completo página por página (`public/*.html`) → tabelas/views utilizadas → endpoints existentes e sugeridos.

---

## 📋 Passo a Passo para Configurar o Supabase

### 1. Configurar as Variáveis de Ambiente no AGON
Abra o arquivo `.env` na raiz do projeto AGON e preencha com as chaves do seu projeto Supabase (**Project Settings > API**):

```env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_PUBLISHABLE_KEY=sua_chave_publica_aqui
SUPABASE_SECRET_KEY=sua_chave_secreta_service_role_aqui
```

*(O cliente em `services/supabaseClient.js` aceita tanto a nomenclatura moderna `SUPABASE_PUBLISHABLE_KEY` / `SUPABASE_SECRET_KEY` quanto a clássica `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY`).*

> ⚠️ **Atenção:** Nunca exponha a chave secreta (`service_role` / `SUPABASE_SECRET_KEY`) no frontend ou em repositórios públicos.

---

### 2. Ordem de Execução das Migrações SQL

Execute os arquivos de `supabase/migrations/` em ordem numérica no **SQL Editor** do painel do Supabase (ou via `npx supabase db push`). Todos os scripts são **100% idempotentes** (`IF NOT EXISTS`, `DROP POLICY IF EXISTS`, `CREATE OR REPLACE`):

| Ordem | Arquivo de Migração | Domínio Coberto |
| :---: | :--- | :--- |
| **01** | [`20261022000001_initial_schema.sql`](./migrations/20261022000001_initial_schema.sql) | Tabelas iniciais: `usuarios`, `question_attempts`, `student_topic_stats`, `ai_conversations`, `ai_messages`, `study_recommendations` |
| **02** | [`20261022000002_row_level_security.sql`](./migrations/20261022000002_row_level_security.sql) | Políticas RLS das 6 tabelas iniciais |
| **03** | [`20261022000003_catalogo_concursos_disciplinas.sql`](./migrations/20261022000003_catalogo_concursos_disciplinas.sql) | Catálogo: `bancas`, `concursos`, `disciplinas`, `assuntos`, `concurso_disciplina_pesos`, `edital_topicos` |
| **04** | [`20261022000004_banco_questoes_cadernos.sql`](./migrations/20261022000004_banco_questoes_cadernos.sql) | Questões: `questoes`, `questao_alternativas`, `questao_comentarios`, `questao_favoritos`, `questao_anotacoes`, `cadernos_questoes`, `caderno_questoes_itens` |
| **05** | [`20261022000005_cursos_aulas_materiais.sql`](./migrations/20261022000005_cursos_aulas_materiais.sql) | Aulas e PDFs: `cursos`, `modulos`, `aulas`, `aula_anexos`, `aula_progresso`, `aula_anotacoes`, `aula_perguntas`, `aula_respostas`, `certificados`, `materiais`, `material_interacoes` |
| **06** | [`20261022000006_simulados_rankings.sql`](./migrations/20261022000006_simulados_rankings.sql) | Simulados: `simulados`, `simulado_questoes`, `simulado_tentativas`, `simulado_respostas` |
| **07** | [`20261022000007_planos_estudo_sm2_flashcards.sql`](./migrations/20261022000007_planos_estudo_sm2_flashcards.sql) | Estudo & SM-2: `aluno_concursos_acompanhados`, `planos_estudo`, `cronograma_tarefas`, `aluno_edital_progresso`, `revisoes_espacadas_sm2`, `caderno_erros`, `flashcards` |
| **08** | [`20261022000008_gamificacao_conquistas_xp.sql`](./migrations/20261022000008_gamificacao_conquistas_xp.sql) | Gamificação: `niveis`, `temporadas`, `conquistas`, `aluno_conquistas`, `xp_ledger`, `dias_estudo`, `atividades_recentes` |
| **09** | [`20261022000009_comunidade_forum_salas.sql`](./migrations/20261022000009_comunidade_forum_salas.sql) | Comunidade: `comunidade_posts`, `comunidade_post_hashtags`, `comunidade_comentarios`, `comunidade_curtidas`, `comunidade_favoritos`, `comunidade_enquete_opcoes`, `comunidade_enquete_votos`, `comunidade_salas_estudo`, `comunidade_sala_presenca`, `comunidade_denuncias` |
| **10** | [`20261022000010_usuarios_seguranca_notificacoes_planos.sql`](./migrations/20261022000010_usuarios_seguranca_notificacoes_planos.sql) | Conta & Planos: `usuario_preferencias`, `notificacoes`, `tokens_redefinicao_senha`, `sessoes_usuario`, `tentativas_login`, `aceites_termos`, `planos_assinatura`, `assinaturas`, `faturas` |
| **11** | [`20261022000011_roadmap_feedback_extensoes_ia.sql`](./migrations/20261022000011_roadmap_feedback_extensoes_ia.sql) | Roadmap & IA: `roadmap_fases`, `roadmap_modulos`, `lista_espera_modulos`, `sugestoes_produto`, `depoimentos`, `ai_generation_logs`, `ai_rate_limits` |
| **12** | [`20261022000012_views_funcoes_rpc.sql`](./migrations/20261022000012_views_funcoes_rpc.sql) | 6 Views analíticas + 5 Funções RPC (Nota Cebraspe, XP/Nível, Streak, Conquistas, SuperMemo SM-2) |
| **13** | [`20261022000013_rls_policies_completas.sql`](./migrations/20261022000013_rls_policies_completas.sql) | Habilitação de RLS e políticas de segurança para todas as tabelas novas + trigger Auth |
| **14** | [`20261022000014_storage_buckets_policies.sql`](./migrations/20261022000014_storage_buckets_policies.sql) | Buckets de Storage (`avatars`, `materiais`, `aulas-anexos`, `comunidade-anexos`) e políticas |
| **15** | [`20261022000015_agon_sessions.sql`](./migrations/20261022000015_agon_sessions.sql) | Sessoes Express persistentes na Vercel |

---

### 3. Executar os Seeds (Dados de Catálogo vs. Demonstração)

1. **[`seed.sql`](./seed.sql) (Obrigatório / Recomendado em Produção):**
   - Contém **apenas o catálogo oficial** extraído das páginas do AGON: 4 bancas, 4 concursos, 8 disciplinas, 13 assuntos, tópicos do edital verticalizado, as 3 questões reais com 5 alternativas cada e comentário do professor, cursos, módulos, 6 videoaulas, 8 materiais em PDF, 3 simulados oficiais, 20 níveis de XP, 6 conquistas/badges, salas Pomodoro, planos de assinatura, fases do roadmap, depoimentos e flashcards oficiais.
2. **[`seed_demo.sql`](./seed_demo.sql) (Opcional — Apenas para Ambiente de Demonstração/Testes):**
   - Popula o usuário fictício `"Davi Brito"` e colegas da comunidade com histórico de 7 dias de estudo, simulados em andamento/concluídos, faturas e enquetes.

---

### 4. Inicialização e Testes Automatizados

No terminal do projeto AGON:

```bash
# Executar a suíte de testes de integração
npm test

# Iniciar o servidor Express (http://localhost:3500)
npm start
```
