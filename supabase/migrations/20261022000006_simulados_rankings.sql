-- ============================================================================
-- AGON — Migração 006: Simulados, Tentativas Cronometradas, Respostas e Rankings
-- ============================================================================
-- Descrição: Cria a estrutura completa para `simulados.html`, incluindo:
-- Catálogo de simulados oficiais e gerados por IA, associação de questões por
-- bloco e peso, tentativas cronometradas com cálculo de nota líquida Cebraspe
-- (1 errada anula 1 certa) ou múltipla escolha, e respostas individuais com
-- marcação para revisão.
-- ============================================================================

-- ============================================================================
-- 1. TABELA: simulados
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simulados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  codigo TEXT UNIQUE, -- Ex: 'SIM-PF-01', 'SIM-RFB-01', 'SIM-TJSP-01'
  titulo TEXT NOT NULL,
  subtitulo TEXT,
  descricao TEXT,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  banca_id UUID REFERENCES public.bancas(id) ON DELETE SET NULL,
  disciplina_foco_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  concurso_sigla TEXT NOT NULL DEFAULT 'pf', -- 'pf', 'rfb', 'tjsp', 'inss'
  banca_nome TEXT NOT NULL DEFAULT 'Cebraspe',
  modalidade TEXT NOT NULL DEFAULT 'multipla_escolha'
    CHECK (modalidade IN ('certo_errado', 'multipla_escolha')),
  regra_pontuacao TEXT NOT NULL DEFAULT 'padrao'
    CHECK (regra_pontuacao IN ('padrao', 'cebraspe_1x1', 'cebraspe_2x1', 'ponderada')),
  fator_penalidade NUMERIC(4,2) NOT NULL DEFAULT 0.00, -- 1.00 para Cebraspe 1 errada anula 1 certa
  total_questoes INTEGER NOT NULL DEFAULT 80,
  duracao_minutos INTEGER NOT NULL DEFAULT 240,
  nota_maxima NUMERIC(6,2) NOT NULL DEFAULT 100.00,
  nota_corte_estimada NUMERIC(6,2) DEFAULT 70.00,
  xp_conclusao INTEGER NOT NULL DEFAULT 350,
  gerado_por_ia BOOLEAN NOT NULL DEFAULT false,
  criado_por_user_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
  ranking_oficial BOOLEAN NOT NULL DEFAULT true,
  total_participantes INTEGER NOT NULL DEFAULT 0,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_simulados_concurso_sigla ON public.simulados(concurso_sigla, ativo);
CREATE INDEX IF NOT EXISTS idx_simulados_concurso_id ON public.simulados(concurso_id);
CREATE INDEX IF NOT EXISTS idx_simulados_criado_por ON public.simulados(criado_por_user_id);

DROP TRIGGER IF EXISTS trg_simulados_updated_at ON public.simulados;
CREATE TRIGGER trg_simulados_updated_at
BEFORE UPDATE ON public.simulados
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. TABELA: simulado_questoes (Composição de questões de cada simulado)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simulado_questoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  simulado_id UUID NOT NULL REFERENCES public.simulados(id) ON DELETE CASCADE,
  questao_id UUID NOT NULL REFERENCES public.questoes(id) ON DELETE CASCADE,
  ordem INTEGER NOT NULL DEFAULT 1,
  bloco TEXT NOT NULL DEFAULT 'Bloco Único',
  peso NUMERIC(4,2) NOT NULL DEFAULT 1.00,
  anulavel_por_erro BOOLEAN NOT NULL DEFAULT false,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (simulado_id, questao_id),
  UNIQUE (simulado_id, ordem)
);

CREATE INDEX IF NOT EXISTS idx_simulado_questoes_simulado ON public.simulado_questoes(simulado_id, ordem);

-- ============================================================================
-- 3. TABELA: simulado_tentativas (Execuções do aluno: Não iniciado / Em andamento / Concluído)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simulado_tentativas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  simulado_id UUID NOT NULL REFERENCES public.simulados(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'em_andamento'
    CHECK (status IN ('nao_iniciado', 'em_andamento', 'concluido', 'abandonado')),
  questao_atual_ordem INTEGER NOT NULL DEFAULT 1,
  questoes_respondidas INTEGER NOT NULL DEFAULT 0,
  total_questoes INTEGER NOT NULL DEFAULT 80,
  acertos INTEGER NOT NULL DEFAULT 0,
  erros INTEGER NOT NULL DEFAULT 0,
  em_branco INTEGER NOT NULL DEFAULT 0,
  pontos_brutos NUMERIC(6,2) NOT NULL DEFAULT 0.00,
  pontos_liquidos NUMERIC(6,2) NOT NULL DEFAULT 0.00,
  percentual_acerto NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  tempo_decorrido_segundos INTEGER NOT NULL DEFAULT 0,
  tempo_limite_segundos INTEGER NOT NULL DEFAULT 14400,
  posicao_ranking INTEGER,
  percentil NUMERIC(5,2),
  desempenho_por_disciplina JSONB NOT NULL DEFAULT '[]'::jsonb,
  xp_ganho INTEGER NOT NULL DEFAULT 0,
  iniciado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finalizado_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_simulado_tentativas_user ON public.simulado_tentativas(user_id, status, atualizado_em DESC);
CREATE INDEX IF NOT EXISTS idx_simulado_tentativas_ranking ON public.simulado_tentativas(simulado_id, status, pontos_liquidos DESC, tempo_decorrido_segundos ASC);

DROP TRIGGER IF EXISTS trg_simulado_tentativas_updated_at ON public.simulado_tentativas;
CREATE TRIGGER trg_simulado_tentativas_updated_at
BEFORE UPDATE ON public.simulado_tentativas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: simulado_respostas (Folha de respostas item a item do simulado)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.simulado_respostas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tentativa_id UUID NOT NULL REFERENCES public.simulado_tentativas(id) ON DELETE CASCADE,
  simulado_questao_id UUID REFERENCES public.simulado_questoes(id) ON DELETE SET NULL,
  questao_id UUID REFERENCES public.questoes(id) ON DELETE SET NULL,
  ordem INTEGER NOT NULL DEFAULT 1,
  disciplina_nome TEXT,
  resposta_marcada TEXT CHECK (resposta_marcada IN ('A', 'B', 'C', 'D', 'E', NULL)),
  gabarito_oficial TEXT,
  acertou BOOLEAN,
  em_branco BOOLEAN NOT NULL DEFAULT true,
  marcada_para_revisao BOOLEAN NOT NULL DEFAULT false,
  pontuacao_item NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  tempo_gasto_segundos INTEGER NOT NULL DEFAULT 0,
  respondida_em TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (tentativa_id, ordem)
);

CREATE INDEX IF NOT EXISTS idx_simulado_respostas_tentativa ON public.simulado_respostas(tentativa_id, ordem);
