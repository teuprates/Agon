-- ============================================================================
-- AGON — Migração 003: Catálogo de Bancas, Concursos, Disciplinas, Assuntos e Editais
-- ============================================================================
-- Descrição: Cria a estrutura base do catálogo pedagógico da plataforma AGON
-- (Bancas examinadoras, Concursos/Carreiras, Disciplinas, Assuntos hierárquicos,
-- Tópicos do Edital Verticalizado e Pesos por Concurso/Disciplina).
-- Totalmente idempotente (IF NOT EXISTS / DROP TRIGGER IF EXISTS).
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. TABELA: bancas
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.bancas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  nome TEXT NOT NULL,
  sigla TEXT NOT NULL,
  descricao TEXT,
  estilo_padrao TEXT NOT NULL DEFAULT 'multipla_escolha'
    CHECK (estilo_padrao IN ('certo_errado', 'multipla_escolha', 'ambos')),
  fator_penalidade_padrao NUMERIC(4,2) NOT NULL DEFAULT 0.00,
  logo_url TEXT,
  site_oficial TEXT,
  ativa BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bancas_slug ON public.bancas(slug);

DROP TRIGGER IF EXISTS trg_bancas_updated_at ON public.bancas;
CREATE TRIGGER trg_bancas_updated_at
BEFORE UPDATE ON public.bancas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. TABELA: concursos
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.concursos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  sigla TEXT NOT NULL,
  nome TEXT NOT NULL,
  orgao TEXT NOT NULL,
  cargo TEXT NOT NULL,
  carreira TEXT NOT NULL DEFAULT 'policial'
    CHECK (carreira IN ('policial', 'fiscal', 'tribunais', 'previdenciaria', 'administrativa', 'bancaria', 'outra')),
  banca_id UUID REFERENCES public.bancas(id) ON DELETE SET NULL,
  ano INTEGER NOT NULL DEFAULT 2026,
  status_edital TEXT NOT NULL DEFAULT 'previsto'
    CHECK (status_edital IN ('previsto', 'autorizado', 'edital_publicado', 'inscricoes_abertas', 'provas_aplicadas', 'encerrado')),
  data_prova DATE,
  vagas INTEGER DEFAULT 0,
  remuneracao_inicial NUMERIC(12,2),
  total_topicos_edital INTEGER NOT NULL DEFAULT 1000,
  ciclo_sugerido_dias INTEGER NOT NULL DEFAULT 120,
  descricao_curta TEXT,
  icone TEXT DEFAULT 'fa-shield-halved',
  cor_tema TEXT DEFAULT 'blue',
  destaque_home BOOLEAN NOT NULL DEFAULT false,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_concursos_slug ON public.concursos(slug);
CREATE INDEX IF NOT EXISTS idx_concursos_carreira ON public.concursos(carreira);
CREATE INDEX IF NOT EXISTS idx_concursos_banca ON public.concursos(banca_id);
CREATE INDEX IF NOT EXISTS idx_concursos_destaque_home ON public.concursos(destaque_home) WHERE destaque_home = true;

DROP TRIGGER IF EXISTS trg_concursos_updated_at ON public.concursos;
CREATE TRIGGER trg_concursos_updated_at
BEFORE UPDATE ON public.concursos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 3. TABELA: disciplinas
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.disciplinas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  nome TEXT NOT NULL,
  nome_curto TEXT NOT NULL,
  area TEXT NOT NULL DEFAULT 'juridica'
    CHECK (area IN ('juridica', 'basica', 'exatas', 'tecnologia', 'contabil_fiscal', 'especifica')),
  descricao TEXT,
  icone TEXT DEFAULT 'fa-book',
  cor_hex TEXT DEFAULT '#23366e',
  cor_badge TEXT DEFAULT 'blue',
  ordem INTEGER NOT NULL DEFAULT 0,
  ativa BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disciplinas_slug ON public.disciplinas(slug);
CREATE INDEX IF NOT EXISTS idx_disciplinas_ordem ON public.disciplinas(ordem);

DROP TRIGGER IF EXISTS trg_disciplinas_updated_at ON public.disciplinas;
CREATE TRIGGER trg_disciplinas_updated_at
BEFORE UPDATE ON public.disciplinas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: assuntos (Hierarquia de tópicos dentro de uma disciplina)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.assuntos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  disciplina_id UUID NOT NULL REFERENCES public.disciplinas(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.assuntos(id) ON DELETE SET NULL,
  slug TEXT NOT NULL,
  nome TEXT NOT NULL,
  descricao TEXT,
  ordem INTEGER NOT NULL DEFAULT 0,
  incidencia_media TEXT NOT NULL DEFAULT 'alta'
    CHECK (incidencia_media IN ('muito_alta', 'alta', 'media', 'baixa')),
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (disciplina_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_assuntos_disciplina ON public.assuntos(disciplina_id, ordem);
CREATE INDEX IF NOT EXISTS idx_assuntos_parent ON public.assuntos(parent_id);

DROP TRIGGER IF EXISTS trg_assuntos_updated_at ON public.assuntos;
CREATE TRIGGER trg_assuntos_updated_at
BEFORE UPDATE ON public.assuntos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 5. TABELA: concurso_disciplina_pesos
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.concurso_disciplina_pesos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concurso_id UUID NOT NULL REFERENCES public.concursos(id) ON DELETE CASCADE,
  disciplina_id UUID NOT NULL REFERENCES public.disciplinas(id) ON DELETE CASCADE,
  bloco TEXT DEFAULT 'Bloco I',
  peso NUMERIC(4,2) NOT NULL DEFAULT 1.00,
  qtd_questoes_previstas INTEGER NOT NULL DEFAULT 10,
  nota_minima NUMERIC(5,2) DEFAULT 0,
  prioridade TEXT NOT NULL DEFAULT 'media'
    CHECK (prioridade IN ('alta', 'media', 'baixa')),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (concurso_id, disciplina_id)
);

CREATE INDEX IF NOT EXISTS idx_concurso_disc_pesos_concurso ON public.concurso_disciplina_pesos(concurso_id);

DROP TRIGGER IF EXISTS trg_concurso_disc_pesos_updated_at ON public.concurso_disciplina_pesos;
CREATE TRIGGER trg_concurso_disc_pesos_updated_at
BEFORE UPDATE ON public.concurso_disciplina_pesos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 6. TABELA: edital_topicos (Itens do Edital Verticalizado por Concurso)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.edital_topicos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concurso_id UUID NOT NULL REFERENCES public.concursos(id) ON DELETE CASCADE,
  disciplina_id UUID NOT NULL REFERENCES public.disciplinas(id) ON DELETE CASCADE,
  assunto_id UUID REFERENCES public.assuntos(id) ON DELETE SET NULL,
  codigo_item TEXT NOT NULL,
  titulo TEXT NOT NULL,
  descricao TEXT,
  peso_incidencia NUMERIC(4,2) NOT NULL DEFAULT 1.00,
  prioridade TEXT NOT NULL DEFAULT 'media'
    CHECK (prioridade IN ('alta', 'media', 'baixa')),
  meta_questoes INTEGER NOT NULL DEFAULT 20,
  ordem INTEGER NOT NULL DEFAULT 0,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (concurso_id, disciplina_id, codigo_item)
);

CREATE INDEX IF NOT EXISTS idx_edital_topicos_concurso_disc ON public.edital_topicos(concurso_id, disciplina_id, ordem);
CREATE INDEX IF NOT EXISTS idx_edital_topicos_assunto ON public.edital_topicos(assunto_id);

DROP TRIGGER IF EXISTS trg_edital_topicos_updated_at ON public.edital_topicos;
CREATE TRIGGER trg_edital_topicos_updated_at
BEFORE UPDATE ON public.edital_topicos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
