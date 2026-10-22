-- ============================================================================
-- AGON — Migração 005: Cursos, Módulos, Videoaulas, Certificados e Materiais
-- ============================================================================
-- Descrição: Cria toda a infraestrutura para as páginas `aulas.html`,
-- `estudos.html` e `materiais.html` (Cursos, Módulos, Videoaulas com transcrição
-- e resumo IA, Anexos da aula, Progresso no vídeo com minuto e velocidade,
-- Anotações com timestamp, Fórum de dúvidas da aula, Certificados e Biblioteca
-- de Materiais com o leitor "Agon Reader").
-- ============================================================================

-- ============================================================================
-- 1. TABELA: cursos
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cursos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  titulo TEXT NOT NULL,
  subtitulo TEXT,
  descricao TEXT,
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  professor_nome TEXT NOT NULL DEFAULT 'Prof. Roberto Vasconcelos',
  professor_cargo TEXT DEFAULT 'Mestre em Direito Público e Especialista em Concursos',
  professor_avatar_url TEXT,
  capa_url TEXT,
  carga_horaria_minutos INTEGER NOT NULL DEFAULT 580,
  total_aulas INTEGER NOT NULL DEFAULT 18,
  nivel TEXT NOT NULL DEFAULT 'intermediario'
    CHECK (nivel IN ('iniciante', 'intermediario', 'avancado', 'alta_performance')),
  emite_certificado BOOLEAN NOT NULL DEFAULT true,
  exclusivo_premium BOOLEAN NOT NULL DEFAULT false,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cursos_slug ON public.cursos(slug);
CREATE INDEX IF NOT EXISTS idx_cursos_disciplina ON public.cursos(disciplina_id);
CREATE INDEX IF NOT EXISTS idx_cursos_concurso ON public.cursos(concurso_id);

DROP TRIGGER IF EXISTS trg_cursos_updated_at ON public.cursos;
CREATE TRIGGER trg_cursos_updated_at
BEFORE UPDATE ON public.cursos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. TABELA: modulos
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.modulos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
  numero INTEGER NOT NULL DEFAULT 1,
  titulo TEXT NOT NULL,
  descricao TEXT,
  bloqueado_por_padrao BOOLEAN NOT NULL DEFAULT false,
  ordem INTEGER NOT NULL DEFAULT 1,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (curso_id, numero)
);

CREATE INDEX IF NOT EXISTS idx_modulos_curso ON public.modulos(curso_id, ordem);

DROP TRIGGER IF EXISTS trg_modulos_updated_at ON public.modulos;
CREATE TRIGGER trg_modulos_updated_at
BEFORE UPDATE ON public.modulos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 3. TABELA: aulas
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aulas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
  modulo_id UUID NOT NULL REFERENCES public.modulos(id) ON DELETE CASCADE,
  assunto_id UUID REFERENCES public.assuntos(id) ON DELETE SET NULL,
  codigo_aula TEXT, -- Ex: 'Aula 04'
  numero INTEGER NOT NULL DEFAULT 1,
  titulo TEXT NOT NULL,
  descricao TEXT,
  resumo_teorico TEXT,
  transcricao_texto TEXT,
  pontos_chave JSONB DEFAULT '[]'::jsonb,
  Jurisprudencia_destaque TEXT,
  video_url TEXT,
  thumbnail_url TEXT,
  duracao_minutos INTEGER NOT NULL DEFAULT 40,
  duracao_segundos INTEGER NOT NULL DEFAULT 2400,
  xp_recompensa INTEGER NOT NULL DEFAULT 150,
  gratuita BOOLEAN NOT NULL DEFAULT false,
  ordem INTEGER NOT NULL DEFAULT 1,
  ativa BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aulas_modulo ON public.aulas(modulo_id, ordem);
CREATE INDEX IF NOT EXISTS idx_aulas_curso ON public.aulas(curso_id, ordem);

DROP TRIGGER IF EXISTS trg_aulas_updated_at ON public.aulas;
CREATE TRIGGER trg_aulas_updated_at
BEFORE UPDATE ON public.aulas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: aula_anexos (Slides, PDFs de apoio, Mapas Mentais da aula)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aula_anexos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aula_id UUID NOT NULL REFERENCES public.aulas(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  tipo_arquivo TEXT NOT NULL DEFAULT 'pdf'
    CHECK (tipo_arquivo IN ('pdf', 'slides', 'mapa_mental', 'planilha', 'link', 'zip')),
  tamanho_bytes BIGINT DEFAULT 0,
  tamanho_label TEXT DEFAULT '2.4 MB',
  paginas INTEGER,
  storage_path TEXT,
  arquivo_url TEXT,
  ordem INTEGER NOT NULL DEFAULT 1,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aula_anexos_aula ON public.aula_anexos(aula_id, ordem);

-- ============================================================================
-- 5. TABELA: aula_progresso (Progresso individual do aluno na aula)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aula_progresso (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
  aula_id UUID NOT NULL REFERENCES public.aulas(id) ON DELETE CASCADE,
  concluida BOOLEAN NOT NULL DEFAULT false,
  favorita BOOLEAN NOT NULL DEFAULT false,
  progresso_percentual NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  posicao_segundos INTEGER NOT NULL DEFAULT 0,
  velocidade_reproducao NUMERIC(3,2) NOT NULL DEFAULT 1.00,
  avaliacao_estrelas INTEGER CHECK (avaliacao_estrelas BETWEEN 1 AND 5),
  concluida_em TIMESTAMPTZ,
  ultimo_acesso_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, aula_id)
);

CREATE INDEX IF NOT EXISTS idx_aula_progresso_user_curso ON public.aula_progresso(user_id, curso_id);
CREATE INDEX IF NOT EXISTS idx_aula_progresso_user_acesso ON public.aula_progresso(user_id, ultimo_acesso_em DESC);

DROP TRIGGER IF EXISTS trg_aula_progresso_updated_at ON public.aula_progresso;
CREATE TRIGGER trg_aula_progresso_updated_at
BEFORE UPDATE ON public.aula_progresso
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 6. TABELA: aula_anotacoes (Caderno de anotações do aluno vinculado à videoaula)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aula_anotacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  aula_id UUID NOT NULL REFERENCES public.aulas(id) ON DELETE CASCADE,
  timestamp_segundos INTEGER DEFAULT 0,
  timestamp_label TEXT DEFAULT '00:00',
  conteudo TEXT NOT NULL,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aula_anotacoes_user_aula ON public.aula_anotacoes(user_id, aula_id, timestamp_segundos);

DROP TRIGGER IF EXISTS trg_aula_anotacoes_updated_at ON public.aula_anotacoes;
CREATE TRIGGER trg_aula_anotacoes_updated_at
BEFORE UPDATE ON public.aula_anotacoes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 7. TABELA: aula_perguntas (Fórum de Dúvidas da Aula)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aula_perguntas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aula_id UUID NOT NULL REFERENCES public.aulas(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  autor_nome TEXT NOT NULL,
  minuto_referencia INTEGER DEFAULT 0,
  pergunta TEXT NOT NULL,
  resolvida BOOLEAN NOT NULL DEFAULT false,
  curtidas INTEGER NOT NULL DEFAULT 0,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aula_perguntas_aula ON public.aula_perguntas(aula_id, criado_em DESC);

DROP TRIGGER IF EXISTS trg_aula_perguntas_updated_at ON public.aula_perguntas;
CREATE TRIGGER trg_aula_perguntas_updated_at
BEFORE UPDATE ON public.aula_perguntas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 8. TABELA: aula_respostas (Respostas de professores ou monitores às dúvidas)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aula_respostas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pergunta_id UUID NOT NULL REFERENCES public.aula_perguntas(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
  autor_nome TEXT NOT NULL,
  autor_papel TEXT NOT NULL DEFAULT 'professor'
    CHECK (autor_papel IN ('professor', 'monitor', 'ia_tutor', 'aluno')),
  resposta TEXT NOT NULL,
  oficial BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aula_respostas_pergunta ON public.aula_respostas(pergunta_id, criado_em ASC);

DROP TRIGGER IF EXISTS trg_aula_respostas_updated_at ON public.aula_respostas;
CREATE TRIGGER trg_aula_respostas_updated_at
BEFORE UPDATE ON public.aula_respostas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 9. TABELA: certificados (Emitidos ao concluir 100% de um curso)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.certificados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo_validacao TEXT UNIQUE NOT NULL,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  curso_id UUID NOT NULL REFERENCES public.cursos(id) ON DELETE CASCADE,
  carga_horaria_horas NUMERIC(5,1) NOT NULL DEFAULT 10.0,
  pdf_url TEXT,
  emitido_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, curso_id)
);

CREATE INDEX IF NOT EXISTS idx_certificados_user ON public.certificados(user_id);

-- ============================================================================
-- 10. TABELA: materiais (Biblioteca Digital — `materiais.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.materiais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  titulo TEXT NOT NULL,
  descricao TEXT,
  categoria TEXT NOT NULL DEFAULT 'apostila'
    CHECK (categoria IN ('apostila', 'resumo', 'mapa', 'lei', 'edital', 'vade_mecum')),
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  disciplina_slug TEXT NOT NULL, -- 'constitucional', 'administrativo', 'portugues', 'informatica', 'raciocinio'
  disciplina_nome TEXT NOT NULL,
  autor_nome TEXT NOT NULL DEFAULT 'Equipe Pedagógica Agon',
  paginas INTEGER NOT NULL DEFAULT 1,
  unidade_paginas TEXT NOT NULL DEFAULT 'páginas'
    CHECK (unidade_paginas IN ('páginas', 'pranchas', 'tabelas')),
  tamanho_bytes BIGINT NOT NULL DEFAULT 1048576,
  tamanho_label TEXT NOT NULL DEFAULT '5.0 MB',
  formato TEXT NOT NULL DEFAULT 'PDF',
  edicao_ano INTEGER NOT NULL DEFAULT 2026,
  destaque_semana BOOLEAN NOT NULL DEFAULT false,
  storage_bucket TEXT DEFAULT 'materiais',
  storage_path TEXT,
  arquivo_url TEXT,
  preview_html TEXT,
  total_downloads INTEGER NOT NULL DEFAULT 0,
  total_leituras INTEGER NOT NULL DEFAULT 0,
  exclusivo_premium BOOLEAN NOT NULL DEFAULT false,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_materiais_categoria_disc ON public.materiais(categoria, disciplina_slug);
CREATE INDEX IF NOT EXISTS idx_materiais_destaque ON public.materiais(destaque_semana) WHERE destaque_semana = true;

DROP TRIGGER IF EXISTS trg_materiais_updated_at ON public.materiais;
CREATE TRIGGER trg_materiais_updated_at
BEFORE UPDATE ON public.materiais
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 11. TABELA: material_interacoes (Favoritos, Downloads e Leitura no Agon Reader)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.material_interacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  material_id UUID NOT NULL REFERENCES public.materiais(id) ON DELETE CASCADE,
  favorito BOOLEAN NOT NULL DEFAULT false,
  baixado BOOLEAN NOT NULL DEFAULT false,
  total_downloads_aluno INTEGER NOT NULL DEFAULT 0,
  ultima_pagina_lida INTEGER NOT NULL DEFAULT 1,
  progresso_leitura_pct NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  ultimo_acesso_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, material_id)
);

CREATE INDEX IF NOT EXISTS idx_material_interacoes_user ON public.material_interacoes(user_id, favorito, ultimo_acesso_em DESC);

DROP TRIGGER IF EXISTS trg_material_interacoes_updated_at ON public.material_interacoes;
CREATE TRIGGER trg_material_interacoes_updated_at
BEFORE UPDATE ON public.material_interacoes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
