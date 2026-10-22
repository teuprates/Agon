-- ============================================================================
-- AGON — Migração 004: Banco de Questões, Alternativas, Comentários e Cadernos
-- ============================================================================
-- Descrição: Cria o banco de questões completo (enunciados, alternativas A-E ou C/E,
-- gabarito oficial e comentado por professores, comentários de alunos, favoritos,
-- anotações privadas e cadernos personalizados de questões) e estende
-- `public.question_attempts` sem quebrar a estrutura atual.
-- ============================================================================

-- ============================================================================
-- 1. TABELA: questoes
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.questoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT UNIQUE NOT NULL, -- Ex: 'Q#24891', 'Q#19302', 'Q#08477'
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  assunto_id UUID REFERENCES public.assuntos(id) ON DELETE SET NULL,
  banca_id UUID REFERENCES public.bancas(id) ON DELETE SET NULL,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  disciplina_slug TEXT NOT NULL, -- Ex: 'constitucional', 'portugues', 'raciocinio'
  disciplina_nome TEXT NOT NULL,
  assunto_nome TEXT NOT NULL,
  banca_sigla TEXT NOT NULL,
  ano INTEGER NOT NULL DEFAULT 2024,
  orgao_cargo TEXT, -- Ex: 'PF — Agente de Polícia Federal'
  modalidade TEXT NOT NULL DEFAULT 'multipla_escolha'
    CHECK (modalidade IN ('multipla_escolha', 'certo_errado')),
  dificuldade TEXT NOT NULL DEFAULT 'media'
    CHECK (dificuldade IN ('facil', 'media', 'dificil')),
  texto_associado TEXT,
  enunciado TEXT NOT NULL,
  gabarito_oficial TEXT NOT NULL, -- 'A','B','C','D','E' ou 'C','E'
  comentario_professor TEXT,
  professor_autor TEXT DEFAULT 'Equipe Pedagógica Agon',
  professor_cargo TEXT DEFAULT 'Especialista em Concursos',
  gerada_por_ia BOOLEAN NOT NULL DEFAULT false,
  anulada BOOLEAN NOT NULL DEFAULT false,
  desatualizada BOOLEAN NOT NULL DEFAULT false,
  total_respostas INTEGER NOT NULL DEFAULT 0,
  total_acertos INTEGER NOT NULL DEFAULT 0,
  ativa BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_questoes_codigo ON public.questoes(codigo);
CREATE INDEX IF NOT EXISTS idx_questoes_filtros ON public.questoes(disciplina_slug, banca_sigla, ano, dificuldade);
CREATE INDEX IF NOT EXISTS idx_questoes_disciplina_id ON public.questoes(disciplina_id);
CREATE INDEX IF NOT EXISTS idx_questoes_assunto_id ON public.questoes(assunto_id);
CREATE INDEX IF NOT EXISTS idx_questoes_banca_id ON public.questoes(banca_id);
CREATE INDEX IF NOT EXISTS idx_questoes_concurso_id ON public.questoes(concurso_id);

DROP TRIGGER IF EXISTS trg_questoes_updated_at ON public.questoes;
CREATE TRIGGER trg_questoes_updated_at
BEFORE UPDATE ON public.questoes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. TABELA: questao_alternativas
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.questao_alternativas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  questao_id UUID NOT NULL REFERENCES public.questoes(id) ON DELETE CASCADE,
  letra TEXT NOT NULL CHECK (letra IN ('A', 'B', 'C', 'D', 'E')),
  texto TEXT NOT NULL,
  correta BOOLEAN NOT NULL DEFAULT false,
  justificativa_alternativa TEXT,
  ordem INTEGER NOT NULL DEFAULT 1,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (questao_id, letra)
);

CREATE INDEX IF NOT EXISTS idx_questao_alternativas_questao ON public.questao_alternativas(questao_id, ordem);

-- ============================================================================
-- 3. TABELA: questao_comentarios (Comentários da comunidade na questão)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.questao_comentarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  questao_id UUID NOT NULL REFERENCES public.questoes(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  conteudo TEXT NOT NULL,
  is_professor BOOLEAN NOT NULL DEFAULT false,
  curtidas INTEGER NOT NULL DEFAULT 0,
  aprovado BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_questao_comentarios_questao ON public.questao_comentarios(questao_id, criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_questao_comentarios_user ON public.questao_comentarios(user_id);

DROP TRIGGER IF EXISTS trg_questao_comentarios_updated_at ON public.questao_comentarios;
CREATE TRIGGER trg_questao_comentarios_updated_at
BEFORE UPDATE ON public.questao_comentarios
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: questao_favoritos (Questões salvas / marcadas pelo aluno)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.questao_favoritos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  questao_id UUID NOT NULL REFERENCES public.questoes(id) ON DELETE CASCADE,
  pasta TEXT DEFAULT 'Geral',
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, questao_id)
);

CREATE INDEX IF NOT EXISTS idx_questao_favoritos_user ON public.questao_favoritos(user_id, criado_em DESC);

-- ============================================================================
-- 5. TABELA: questao_anotacoes (Notas privadas do aluno por questão)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.questao_anotacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  questao_id UUID NOT NULL REFERENCES public.questoes(id) ON DELETE CASCADE,
  conteudo TEXT NOT NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, questao_id)
);

CREATE INDEX IF NOT EXISTS idx_questao_anotacoes_user ON public.questao_anotacoes(user_id);

DROP TRIGGER IF EXISTS trg_questao_anotacoes_updated_at ON public.questao_anotacoes;
CREATE TRIGGER trg_questao_anotacoes_updated_at
BEFORE UPDATE ON public.questao_anotacoes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 6. TABELA: cadernos_questoes (Cadernos / filtros salvos pelo aluno)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cadernos_questoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  descricao TEXT,
  filtros_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  total_questoes INTEGER NOT NULL DEFAULT 0,
  questoes_respondidas INTEGER NOT NULL DEFAULT 0,
  favorito BOOLEAN NOT NULL DEFAULT false,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cadernos_questoes_user ON public.cadernos_questoes(user_id, criado_em DESC);

DROP TRIGGER IF EXISTS trg_cadernos_questoes_updated_at ON public.cadernos_questoes;
CREATE TRIGGER trg_cadernos_questoes_updated_at
BEFORE UPDATE ON public.cadernos_questoes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 7. TABELA: caderno_questoes_itens
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.caderno_questoes_itens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caderno_id UUID NOT NULL REFERENCES public.cadernos_questoes(id) ON DELETE CASCADE,
  questao_id UUID NOT NULL REFERENCES public.questoes(id) ON DELETE CASCADE,
  ordem INTEGER NOT NULL DEFAULT 1,
  respondida BOOLEAN NOT NULL DEFAULT false,
  acertou BOOLEAN,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (caderno_id, questao_id)
);

CREATE INDEX IF NOT EXISTS idx_caderno_itens_caderno ON public.caderno_questoes_itens(caderno_id, ordem);

-- ============================================================================
-- 8. EXTENSÃO NÃO-DESTRUTIVA DE `public.question_attempts`
-- ============================================================================
-- Compatibiliza 100% os nomes de colunas usados em `services/database.js`
-- com a migração inicial 001.
ALTER TABLE public.question_attempts
  ALTER COLUMN resposta_aluno DROP NOT NULL,
  ALTER COLUMN gabarito DROP NOT NULL;

ALTER TABLE public.question_attempts
  ADD COLUMN IF NOT EXISTS subassunto TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS resposta_selecionada TEXT,
  ADD COLUMN IF NOT EXISTS resposta_correta TEXT,
  ADD COLUMN IF NOT EXISTS tempo_gasto_segundos INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS origem TEXT DEFAULT 'oficial',
  ADD COLUMN IF NOT EXISTS tentativa_num INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS questao_uuid UUID REFERENCES public.questoes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS caderno_id UUID REFERENCES public.cadernos_questoes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS xp_ganho INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS modo_resolucao TEXT NOT NULL DEFAULT 'avulsa'
    CHECK (modo_resolucao IN ('avulsa', 'caderno', 'simulado', 'revisao_sm2', 'ia_tutor'));

CREATE INDEX IF NOT EXISTS idx_question_attempts_questao_uuid ON public.question_attempts(questao_uuid);
