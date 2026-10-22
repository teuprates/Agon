-- ============================================================================
-- AGON — Migração 011: Roadmap, Lista de Espera, Sugestões, Depoimentos e Extensões IA
-- ============================================================================
-- Descrição: Cria as tabelas para `em-breve.html`, `home.html`, `ia-tutor.html`
-- e `desempenho.html`:
-- `roadmap_fases`, `roadmap_modulos`, `lista_espera_modulos`, `sugestoes_produto`,
-- `depoimentos`, extensões não-destrutivas em `ai_messages` e `study_recommendations`,
-- além de `ai_generation_logs` e `ai_rate_limits`.
-- ============================================================================

-- ============================================================================
-- 1. TABELA: roadmap_fases (Cronograma de Lançamentos em `em-breve.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.roadmap_fases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero_fase INTEGER UNIQUE NOT NULL,
  titulo TEXT NOT NULL, -- Ex: 'Fase 3: Videoaulas & Materiais'
  descricao TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'planejada'
    CHECK (status IN ('concluida', 'disponivel', 'em_desenvolvimento', 'proxima', 'planejada')),
  progresso_percentual INTEGER NOT NULL DEFAULT 0 CHECK (progresso_percentual BETWEEN 0 AND 100),
  previsao_entrega TEXT, -- Ex: 'Novembro 2026'
  ordem INTEGER NOT NULL DEFAULT 1,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_roadmap_fases_updated_at ON public.roadmap_fases;
CREATE TRIGGER trg_roadmap_fases_updated_at
BEFORE UPDATE ON public.roadmap_fases
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. TABELA: roadmap_modulos (Módulos específicos de `em-breve.html?modulo=...`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.roadmap_modulos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL, -- 'aulas', 'planos-estudo', 'materiais', 'configuracoes', 'geral'
  badge_titulo TEXT NOT NULL,
  titulo TEXT NOT NULL,
  descricao TEXT NOT NULL,
  icone TEXT NOT NULL DEFAULT 'fa-rocket',
  progresso_desenvolvimento INTEGER NOT NULL DEFAULT 78,
  previsao_lancamento TEXT DEFAULT 'Novembro 2026',
  status_etapa TEXT DEFAULT 'Testes Internos & Revisão Pedagógica',
  entregaveis_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  total_inscritos_espera INTEGER NOT NULL DEFAULT 342,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_roadmap_modulos_updated_at ON public.roadmap_modulos;
CREATE TRIGGER trg_roadmap_modulos_updated_at
BEFORE UPDATE ON public.roadmap_modulos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 3. TABELA: lista_espera_modulos ("Quero ser avisado" em `em-breve.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.lista_espera_modulos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  modulo_slug TEXT NOT NULL DEFAULT 'geral',
  email TEXT NOT NULL,
  user_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
  notificado BOOLEAN NOT NULL DEFAULT false,
  notificado_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (modulo_slug, email)
);

CREATE INDEX IF NOT EXISTS idx_lista_espera_modulo ON public.lista_espera_modulos(modulo_slug, criado_em DESC);

-- ============================================================================
-- 4. TABELA: sugestoes_produto (Modal "Enviar Sugestão" em `em-breve.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.sugestoes_produto (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
  autor_nome TEXT,
  autor_email TEXT,
  modulo_relacionado TEXT NOT NULL DEFAULT 'geral'
    CHECK (modulo_relacionado IN ('aulas', 'planos-estudo', 'materiais', 'configuracoes', 'questoes', 'simulados', 'ia-tutor', 'comunidade', 'geral')),
  sugestao_texto TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'recebida'
    CHECK (status IN ('recebida', 'em_analise', 'planejada', 'implementada', 'arquivada')),
  votos_apoio INTEGER NOT NULL DEFAULT 1,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sugestoes_produto_modulo ON public.sugestoes_produto(modulo_relacionado, status, criado_em DESC);

DROP TRIGGER IF EXISTS trg_sugestoes_produto_updated_at ON public.sugestoes_produto;
CREATE TRIGGER trg_sugestoes_produto_updated_at
BEFORE UPDATE ON public.sugestoes_produto
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 5. TABELA: depoimentos (Seção `#depoimentos` em `home.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.depoimentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  nome_aluno TEXT NOT NULL, -- Ex: 'Lucas Vasconcelos'
  cargo_aprovado TEXT NOT NULL, -- Ex: 'Aprovado Polícia Federal'
  cidade_uf TEXT NOT NULL DEFAULT 'Brasília, DF',
  avatar_url TEXT DEFAULT 'assets/img/perfil.jpg',
  texto TEXT NOT NULL,
  nota_estrelas INTEGER NOT NULL DEFAULT 5 CHECK (nota_estrelas BETWEEN 1 AND 5),
  destaque_home BOOLEAN NOT NULL DEFAULT true,
  aprovado_moderacao BOOLEAN NOT NULL DEFAULT true,
  ordem INTEGER NOT NULL DEFAULT 1,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_depoimentos_home ON public.depoimentos(aprovado_moderacao, destaque_home, ordem);

DROP TRIGGER IF EXISTS trg_depoimentos_updated_at ON public.depoimentos;
CREATE TRIGGER trg_depoimentos_updated_at
BEFORE UPDATE ON public.depoimentos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 6. EXTENSÕES NÃO-DESTRUTIVAS DE IA & RECOMENDAÇÕES (`ia-tutor.html`, `desempenho.html`)
-- ============================================================================
ALTER TABLE public.ai_messages
  ADD COLUMN IF NOT EXISTS modelo_utilizado TEXT DEFAULT 'gemini-2.5-flash',
  ADD COLUMN IF NOT EXISTS tokens_prompt INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tokens_resposta INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS latencia_ms INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS feedback_util BOOLEAN;

ALTER TABLE public.study_recommendations
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pendente',
  ADD COLUMN IF NOT EXISTS gerado_por TEXT DEFAULT 'regras_estatisticas',
  ADD COLUMN IF NOT EXISTS atualizado_em TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS concluida BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS concluida_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS link_acao TEXT DEFAULT '/questoes',
  ADD COLUMN IF NOT EXISTS meta_questoes_sugerida INTEGER DEFAULT 15;

-- ============================================================================
-- 7. TABELA: ai_generation_logs (Auditoria de chamadas Gemini: Chat, Simulados IA, Diagnóstico)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_generation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  conversation_id TEXT REFERENCES public.ai_conversations(id) ON DELETE SET NULL,
  funcionalidade TEXT NOT NULL DEFAULT 'zuka_chat'
    CHECK (funcionalidade IN ('zuka_chat', 'explicacao_questao', 'gerador_simulado_ia', 'diagnostico_desempenho', 'resumo_aula')),
  modelo TEXT NOT NULL DEFAULT 'gemini-2.5-flash',
  tokens_entrada INTEGER NOT NULL DEFAULT 0,
  tokens_saida INTEGER NOT NULL DEFAULT 0,
  latencia_ms INTEGER NOT NULL DEFAULT 0,
  sucesso BOOLEAN NOT NULL DEFAULT true,
  erro_mensagem TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_generation_logs_user_data ON public.ai_generation_logs(user_id, criado_em DESC);

-- ============================================================================
-- 8. TABELA: ai_rate_limits (Controle de cota diária por usuário na Zuka IA)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  data_referencia DATE NOT NULL DEFAULT CURRENT_DATE,
  mensagens_enviadas INTEGER NOT NULL DEFAULT 0,
  simulados_ia_gerados INTEGER NOT NULL DEFAULT 0,
  tokens_consumidos_dia INTEGER NOT NULL DEFAULT 0,
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, data_referencia)
);

CREATE INDEX IF NOT EXISTS idx_ai_rate_limits_user_data ON public.ai_rate_limits(user_id, data_referencia DESC);
