-- ============================================================================
-- AGON — Migração 007: Planos de Estudo, Edital Verticalizado, SM-2 e Flashcards
-- ============================================================================
-- Descrição: Cria as tabelas para `planos-estudo.html`, `estudos.html` e
-- `index.html` (Concursos acompanhados pelo aluno, Planos e Ciclos de Estudo,
-- Tarefas do Cronograma Semanal, Progresso no Edital Verticalizado, Repetição
-- Espaçada com algoritmo SM-2 24h/7d/30d, Caderno de Erros e Flashcards).
-- ============================================================================

-- ============================================================================
-- 1. TABELA: aluno_concursos_acompanhados (Cards "Próximos Concursos" do Dashboard)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aluno_concursos_acompanhados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  concurso_id UUID NOT NULL REFERENCES public.concursos(id) ON DELETE CASCADE,
  foco_principal BOOLEAN NOT NULL DEFAULT false,
  status_acompanhamento TEXT NOT NULL DEFAULT 'em_andamento'
    CHECK (status_acompanhamento IN ('foco_principal', 'em_andamento', 'iniciando', 'pausado', 'concluido')),
  topicos_concluidos INTEGER NOT NULL DEFAULT 0,
  total_topicos INTEGER NOT NULL DEFAULT 1000,
  progresso_percentual NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, concurso_id)
);

CREATE INDEX IF NOT EXISTS idx_aluno_concursos_user ON public.aluno_concursos_acompanhados(user_id, foco_principal DESC);

DROP TRIGGER IF EXISTS trg_aluno_concursos_updated_at ON public.aluno_concursos_acompanhados;
CREATE TRIGGER trg_aluno_concursos_updated_at
BEFORE UPDATE ON public.aluno_concursos_acompanhados
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. TABELA: planos_estudo (Configuração da Meta & Ciclo em `planos-estudo.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.planos_estudo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  titulo TEXT NOT NULL DEFAULT 'Ciclo de Alta Performance',
  cargo_alvo_display TEXT NOT NULL DEFAULT 'Polícia Federal — Agente',
  data_prova_estimada DATE,
  horas_meta_diaria NUMERIC(4,2) NOT NULL DEFAULT 3.50,
  horas_meta_semanal NUMERIC(5,2) NOT NULL DEFAULT 22.00,
  dias_estudo_semana INTEGER[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,6], -- 1=Seg .. 7=Dom
  metodo_ciclo TEXT NOT NULL DEFAULT 'adaptativo_ia'
    CHECK (metodo_ciclo IN ('adaptativo_ia', 'grade_fixa', 'ciclo_rotativo', 'pomodoro_intensivo')),
  incluir_revisoes_sm2 BOOLEAN NOT NULL DEFAULT true,
  incluir_simulado_fim_semana BOOLEAN NOT NULL DEFAULT true,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_planos_estudo_user ON public.planos_estudo(user_id, ativo DESC);

DROP TRIGGER IF EXISTS trg_planos_estudo_updated_at ON public.planos_estudo;
CREATE TRIGGER trg_planos_estudo_updated_at
BEFORE UPDATE ON public.planos_estudo
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 3. TABELA: cronograma_tarefas (Grade semanal Seg–Dom e checklist interativo)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cronograma_tarefas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plano_id UUID REFERENCES public.planos_estudo(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  assunto_id UUID REFERENCES public.assuntos(id) ON DELETE SET NULL,
  disciplina_nome TEXT NOT NULL,
  titulo TEXT NOT NULL, -- Ex: 'Teoria: Remédios Constitucionais (HC e HD)'
  descricao TEXT,
  tipo_atividade TEXT NOT NULL DEFAULT 'teoria'
    CHECK (tipo_atividade IN ('teoria', 'questoes', 'revisao', 'lei_seca', 'simulado', 'redacao', 'descanso')),
  dia_semana INTEGER NOT NULL CHECK (dia_semana BETWEEN 1 AND 7), -- 1=Seg .. 7=Dom
  data_agendada DATE,
  duracao_prevista_minutos INTEGER NOT NULL DEFAULT 60,
  duracao_realizada_minutos INTEGER NOT NULL DEFAULT 0,
  qtd_questoes_meta INTEGER DEFAULT 0,
  cor_card TEXT NOT NULL DEFAULT 'blue',
  ordem INTEGER NOT NULL DEFAULT 1,
  concluida BOOLEAN NOT NULL DEFAULT false,
  concluida_em TIMESTAMPTZ,
  xp_recompensa INTEGER NOT NULL DEFAULT 50,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cronograma_tarefas_user_dia ON public.cronograma_tarefas(user_id, dia_semana, ordem);
CREATE INDEX IF NOT EXISTS idx_cronograma_tarefas_user_data ON public.cronograma_tarefas(user_id, data_agendada);

DROP TRIGGER IF EXISTS trg_cronograma_tarefas_updated_at ON public.cronograma_tarefas;
CREATE TRIGGER trg_cronograma_tarefas_updated_at
BEFORE UPDATE ON public.cronograma_tarefas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: aluno_edital_progresso (Tabela Edital Verticalizado & Progresso)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aluno_edital_progresso (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  edital_topico_id UUID REFERENCES public.edital_topicos(id) ON DELETE CASCADE,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE CASCADE,
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  disciplina_nome TEXT NOT NULL,
  topicos_concluidos INTEGER NOT NULL DEFAULT 0,
  total_topicos INTEGER NOT NULL DEFAULT 15,
  teoria_concluida BOOLEAN NOT NULL DEFAULT false,
  resumo_concluido BOOLEAN NOT NULL DEFAULT false,
  revisao_em_dia BOOLEAN NOT NULL DEFAULT false,
  questoes_resolvidas INTEGER NOT NULL DEFAULT 0,
  questoes_acertos INTEGER NOT NULL DEFAULT 0,
  taxa_acerto NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  progresso_cobertura NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  prioridade TEXT NOT NULL DEFAULT 'media'
    CHECK (prioridade IN ('alta', 'media', 'baixa')),
  ultimo_estudo_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, concurso_id, disciplina_nome)
);

CREATE INDEX IF NOT EXISTS idx_aluno_edital_progresso_user ON public.aluno_edital_progresso(user_id, concurso_id);

DROP TRIGGER IF EXISTS trg_aluno_edital_progresso_updated_at ON public.aluno_edital_progresso;
CREATE TRIGGER trg_aluno_edital_progresso_updated_at
BEFORE UPDATE ON public.aluno_edital_progresso
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 5. TABELA: revisoes_espacadas_sm2 (Repetição Espaçada 24h / 7d / 30d / SM-2)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.revisoes_espacadas_sm2 (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  assunto_id UUID REFERENCES public.assuntos(id) ON DELETE SET NULL,
  disciplina_nome TEXT NOT NULL,
  assunto_nome TEXT NOT NULL,
  ciclo_label TEXT NOT NULL DEFAULT '24h'
    CHECK (ciclo_label IN ('24h', '7d', '15d', '30d', 'sm2_custom')),
  repeticoes INTEGER NOT NULL DEFAULT 0,
  fator_facilidade NUMERIC(4,2) NOT NULL DEFAULT 2.50, -- EF padrão do algoritmo SuperMemo SM-2
  intervalo_dias INTEGER NOT NULL DEFAULT 1,
  ultima_nota_qualidade INTEGER CHECK (ultima_nota_qualidade BETWEEN 0 AND 5),
  proxima_revisao_em DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'pendente'
    CHECK (status IN ('atrasada', 'para_hoje', 'pendente', 'concluida')),
  qtd_cards_revisar INTEGER NOT NULL DEFAULT 15,
  ultima_revisao_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_revisoes_sm2_user_proxima ON public.revisoes_espacadas_sm2(user_id, status, proxima_revisao_em ASC);

DROP TRIGGER IF EXISTS trg_revisoes_sm2_updated_at ON public.revisoes_espacadas_sm2;
CREATE TRIGGER trg_revisoes_sm2_updated_at
BEFORE UPDATE ON public.revisoes_espacadas_sm2
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 6. TABELA: caderno_erros (Itens errados em questões/simulados para revisão)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.caderno_erros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  questao_id UUID REFERENCES public.questoes(id) ON DELETE SET NULL,
  question_codigo TEXT NOT NULL,
  disciplina_nome TEXT NOT NULL,
  assunto_nome TEXT NOT NULL,
  banca_nome TEXT,
  motivo_erro TEXT DEFAULT 'duvida_teorica'
    CHECK (motivo_erro IN ('falta_base', 'pegadinha_banca', 'falta_atencao', 'duvida_teorica', 'esquecimento_lei')),
  anotacao_superacao TEXT,
  vezes_errada INTEGER NOT NULL DEFAULT 1,
  dominada BOOLEAN NOT NULL DEFAULT false,
  dominada_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, question_codigo)
);

CREATE INDEX IF NOT EXISTS idx_caderno_erros_user ON public.caderno_erros(user_id, dominada, criado_em DESC);

DROP TRIGGER IF EXISTS trg_caderno_erros_updated_at ON public.caderno_erros;
CREATE TRIGGER trg_caderno_erros_updated_at
BEFORE UPDATE ON public.caderno_erros
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 7. TABELA: flashcards (Revisão ativa Frente/Verso com SM-2)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.flashcards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT REFERENCES public.usuarios(id) ON DELETE CASCADE, -- NULL = flashcard oficial do catálogo Agon
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  assunto_id UUID REFERENCES public.assuntos(id) ON DELETE SET NULL,
  disciplina_nome TEXT NOT NULL,
  assunto_nome TEXT NOT NULL,
  frente TEXT NOT NULL,
  verso TEXT NOT NULL,
  mnemonico TEXT,
  oficial_agon BOOLEAN NOT NULL DEFAULT false,
  repeticoes INTEGER NOT NULL DEFAULT 0,
  fator_facilidade NUMERIC(4,2) NOT NULL DEFAULT 2.50,
  intervalo_dias INTEGER NOT NULL DEFAULT 1,
  proxima_revisao_em DATE DEFAULT CURRENT_DATE,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_flashcards_user ON public.flashcards(user_id, proxima_revisao_em);
CREATE INDEX IF NOT EXISTS idx_flashcards_oficial ON public.flashcards(oficial_agon, disciplina_nome);

DROP TRIGGER IF EXISTS trg_flashcards_updated_at ON public.flashcards;
CREATE TRIGGER trg_flashcards_updated_at
BEFORE UPDATE ON public.flashcards
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
