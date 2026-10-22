-- ============================================================================
-- AGON — Migração 008: Gamificação, Níveis, Temporadas, Conquistas e XP Ledger
-- ============================================================================
-- Descrição: Cria o motor de gamificação para `conquistas.html` e `index.html`:
-- Tabela de Níveis (1..20), Temporadas de Ranking, Catálogo de Conquistas/Badges,
-- Progresso e Desbloqueio de Conquistas por aluno, Livro-Razão de XP (xp_ledger),
-- Calendário de Sequência de Estudos (dias_estudo) e Feed de Atividades Recentes.
-- ============================================================================

-- ============================================================================
-- 1. TABELA: niveis (Catálogo de Níveis 1..20)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.niveis (
  nivel INTEGER PRIMARY KEY CHECK (nivel >= 1),
  titulo TEXT NOT NULL, -- Ex: Nível 12 = 'Concurseiro Dedicado', Nível 13 = 'Mestre dos Concursos'
  xp_minimo INTEGER NOT NULL,
  xp_proximo_nivel INTEGER NOT NULL,
  icone TEXT NOT NULL DEFAULT 'fa-medal',
  cor_badge TEXT NOT NULL DEFAULT 'blue',
  recompensa_descricao TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. TABELA: temporadas (Temporadas mensais/trimestrais de Ranking XP)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.temporadas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT UNIQUE NOT NULL, -- Ex: '2026-T4-OUTUBRO'
  nome TEXT NOT NULL, -- Ex: 'Temporada Outubro 2026'
  descricao TEXT,
  data_inicio DATE NOT NULL,
  data_fim DATE NOT NULL,
  ativa BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_temporadas_ativa ON public.temporadas(ativa) WHERE ativa = true;

DROP TRIGGER IF EXISTS trg_temporadas_updated_at ON public.temporadas;
CREATE TRIGGER trg_temporadas_updated_at
BEFORE UPDATE ON public.temporadas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 3. TABELA: conquistas (Catálogo de Badges e Medalhas de `conquistas.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.conquistas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL, -- 'foco_total', 'estudioso', 'centuriao', 'mestre', 'premium', 'maratonista'
  titulo TEXT NOT NULL,
  descricao_curta TEXT NOT NULL, -- Ex: '7 dias seguidos'
  descricao_detalhada TEXT NOT NULL, -- Ex: 'Estudou por 7 dias ininterruptos cumprindo a meta diária.'
  icone TEXT NOT NULL DEFAULT 'fa-trophy',
  cor_tema TEXT NOT NULL DEFAULT 'orange'
    CHECK (cor_tema IN ('orange', 'blue', 'green', 'purple', 'cyan', 'amber', 'red')),
  xp_recompensa INTEGER NOT NULL DEFAULT 200,
  regra_tipo TEXT NOT NULL
    CHECK (regra_tipo IN ('streak_dias', 'horas_estudo', 'questoes_resolvidas', 'nota_simulado', 'assinatura_ativa', 'posts_comunidade', 'aulas_concluidas')),
  meta_valor NUMERIC(10,2) NOT NULL DEFAULT 1,
  unidade_meta TEXT NOT NULL DEFAULT 'dias',
  ordem INTEGER NOT NULL DEFAULT 1,
  ativa BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conquistas_slug ON public.conquistas(slug);
CREATE INDEX IF NOT EXISTS idx_conquistas_ordem ON public.conquistas(ordem);

DROP TRIGGER IF EXISTS trg_conquistas_updated_at ON public.conquistas;
CREATE TRIGGER trg_conquistas_updated_at
BEFORE UPDATE ON public.conquistas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: aluno_conquistas (Progresso e desbloqueio de cada badge pelo aluno)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aluno_conquistas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  conquista_id UUID NOT NULL REFERENCES public.conquistas(id) ON DELETE CASCADE,
  progresso_atual NUMERIC(10,2) NOT NULL DEFAULT 0,
  progresso_meta NUMERIC(10,2) NOT NULL DEFAULT 1,
  progresso_percentual NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  desbloqueada BOOLEAN NOT NULL DEFAULT false,
  desbloqueada_em TIMESTAMPTZ,
  notificada BOOLEAN NOT NULL DEFAULT false,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, conquista_id)
);

CREATE INDEX IF NOT EXISTS idx_aluno_conquistas_user ON public.aluno_conquistas(user_id, desbloqueada DESC);

DROP TRIGGER IF EXISTS trg_aluno_conquistas_updated_at ON public.aluno_conquistas;
CREATE TRIGGER trg_aluno_conquistas_updated_at
BEFORE UPDATE ON public.aluno_conquistas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 5. TABELA: xp_ledger (Histórico auditável de ganhos de XP por temporada)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.xp_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  temporada_id UUID REFERENCES public.temporadas(id) ON DELETE SET NULL,
  origem_tipo TEXT NOT NULL
    CHECK (origem_tipo IN ('questao_correta', 'bateria_questoes', 'videoaula_concluida', 'simulado_concluido', 'conquista_desbloqueada', 'meta_diaria', 'post_comunidade', 'bonus_streak')),
  origem_id TEXT,
  descricao TEXT NOT NULL,
  xp_delta INTEGER NOT NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_xp_ledger_user_data ON public.xp_ledger(user_id, criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_xp_ledger_temporada ON public.xp_ledger(temporada_id, user_id);

-- ============================================================================
-- 6. TABELA: dias_estudo (Calendário de Sequência / Streak e Evolução Diária)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.dias_estudo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  data_estudo DATE NOT NULL,
  minutos_liquidos INTEGER NOT NULL DEFAULT 0,
  horas_liquidas NUMERIC(5,2) GENERATED ALWAYS AS (ROUND(minutos_liquidos / 60.0, 2)) STORED,
  questoes_resolvidas INTEGER NOT NULL DEFAULT 0,
  questoes_acertos INTEGER NOT NULL DEFAULT 0,
  aulas_assistidas INTEGER NOT NULL DEFAULT 0,
  xp_ganho_dia INTEGER NOT NULL DEFAULT 0,
  meta_diaria_cumprida BOOLEAN NOT NULL DEFAULT false,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, data_estudo)
);

CREATE INDEX IF NOT EXISTS idx_dias_estudo_user_data ON public.dias_estudo(user_id, data_estudo DESC);

DROP TRIGGER IF EXISTS trg_dias_estudo_updated_at ON public.dias_estudo;
CREATE TRIGGER trg_dias_estudo_updated_at
BEFORE UPDATE ON public.dias_estudo
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 7. TABELA: atividades_recentes (Card "Atividades Recentes" em `index.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.atividades_recentes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL
    CHECK (tipo IN ('questoes', 'aula', 'simulado', 'conquista', 'material', 'plano', 'comunidade')),
  titulo TEXT NOT NULL, -- Ex: '20 questões Dir.Adm', 'Princípios Adm. Pública', 'Simulado PF Rodada 3'
  subtitulo TEXT NOT NULL, -- Ex: 'Direito Administrativo • 85% acertos'
  xp_ganho INTEGER NOT NULL DEFAULT 0,
  icone TEXT NOT NULL DEFAULT 'fa-list-check',
  cor_badge TEXT NOT NULL DEFAULT 'green',
  referencia_id TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_atividades_recentes_user ON public.atividades_recentes(user_id, criado_em DESC);
