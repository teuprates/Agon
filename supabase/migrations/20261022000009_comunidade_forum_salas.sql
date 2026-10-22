-- ============================================================================
-- AGON — Migração 009: Comunidade, Fórum, Enquetes, Salas Pomodoro e Moderação
-- ============================================================================
-- Descrição: Cria toda a estrutura social para `comunidade.html`:
-- Publicações categorizadas (dúvidas, resumos, editais, motivação), Hashtags
-- em alta, Comentários/Respostas (com selo de resposta verificada), Curtidas,
-- Favoritos (Salvos), Enquetes interativas com votos únicos, Salas de Estudo
-- Ao Vivo (Pomodoro) com presença online e Denúncias/Moderação.
-- ============================================================================

-- ============================================================================
-- 1. TABELA: comunidade_posts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  disciplina_id UUID REFERENCES public.disciplinas(id) ON DELETE SET NULL,
  autor_nome TEXT NOT NULL,
  autor_avatar_url TEXT,
  autor_cargo_meta TEXT DEFAULT 'Concurseiro Ativo',
  autor_badge TEXT DEFAULT 'Geral', -- Ex: 'Polícia Federal', 'Língua Portuguesa', 'Receita Federal', 'TJ-SP'
  autor_cor_badge TEXT DEFAULT 'blue',
  autor_subtitulo TEXT, -- Ex: 'Meta: Agente PF • Nível 14'
  categoria TEXT NOT NULL DEFAULT 'duvidas'
    CHECK (categoria IN ('duvidas', 'resumos', 'editais', 'motivacao', 'geral')),
  titulo TEXT,
  conteudo TEXT NOT NULL,
  codigo_formatado TEXT, -- Bloco `<pre>` opcional (ex: mnemônicos / esquemas)
  possui_enquete BOOLEAN NOT NULL DEFAULT false,
  anexo_url TEXT,
  anexo_nome TEXT,
  anexo_tipo TEXT CHECK (anexo_tipo IN ('imagem', 'pdf', 'resumo', NULL)),
  fixado BOOLEAN NOT NULL DEFAULT false,
  fechado BOOLEAN NOT NULL DEFAULT false,
  total_curtidas INTEGER NOT NULL DEFAULT 0,
  total_comentarios INTEGER NOT NULL DEFAULT 0,
  total_favoritos INTEGER NOT NULL DEFAULT 0,
  total_compartilhamentos INTEGER NOT NULL DEFAULT 0,
  status_moderacao TEXT NOT NULL DEFAULT 'ativo'
    CHECK (status_moderacao IN ('ativo', 'oculto', 'removido')),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comunidade_posts_feed ON public.comunidade_posts(status_moderacao, fixado DESC, criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_comunidade_posts_categoria ON public.comunidade_posts(categoria, criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_comunidade_posts_user ON public.comunidade_posts(user_id);

DROP TRIGGER IF EXISTS trg_comunidade_posts_updated_at ON public.comunidade_posts;
CREATE TRIGGER trg_comunidade_posts_updated_at
BEFORE UPDATE ON public.comunidade_posts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. TABELA: comunidade_post_hashtags (Tópicos em Alta / Trending Tags)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_post_hashtags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.comunidade_posts(id) ON DELETE CASCADE,
  hashtag TEXT NOT NULL, -- Ex: '#PolíciaFederal2026', '#DireitoConstitucional', '#DicasDePortuguês'
  descricao_topico TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, hashtag)
);

CREATE INDEX IF NOT EXISTS idx_comunidade_hashtags_tag ON public.comunidade_post_hashtags(hashtag);
CREATE INDEX IF NOT EXISTS idx_comunidade_hashtags_post ON public.comunidade_post_hashtags(post_id);

-- ============================================================================
-- 3. TABELA: comunidade_comentarios (Respostas aos posts e selo Monitor/Verificado)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_comentarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.comunidade_posts(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.comunidade_comentarios(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  autor_nome TEXT NOT NULL,
  autor_avatar_url TEXT,
  autor_papel TEXT NOT NULL DEFAULT 'aluno'
    CHECK (autor_papel IN ('aluno', 'monitor', 'professor', 'admin')),
  conteudo TEXT NOT NULL,
  resposta_verificada BOOLEAN NOT NULL DEFAULT false,
  total_curtidas INTEGER NOT NULL DEFAULT 0,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comunidade_comentarios_post ON public.comunidade_comentarios(post_id, criado_em ASC);
CREATE INDEX IF NOT EXISTS idx_comunidade_comentarios_user ON public.comunidade_comentarios(user_id);

DROP TRIGGER IF EXISTS trg_comunidade_comentarios_updated_at ON public.comunidade_comentarios;
CREATE TRIGGER trg_comunidade_comentarios_updated_at
BEFORE UPDATE ON public.comunidade_comentarios
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: comunidade_curtidas (Likes em posts)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_curtidas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.comunidade_posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_comunidade_curtidas_post ON public.comunidade_curtidas(post_id);
CREATE INDEX IF NOT EXISTS idx_comunidade_curtidas_user ON public.comunidade_curtidas(user_id);

-- ============================================================================
-- 5. TABELA: comunidade_favoritos (Aba "Salvos" na Comunidade)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_favoritos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.comunidade_posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_comunidade_favoritos_user ON public.comunidade_favoritos(user_id, criado_em DESC);

-- ============================================================================
-- 6. TABELA: comunidade_enquete_opcoes (Opções de votação em posts de enquete)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_enquete_opcoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.comunidade_posts(id) ON DELETE CASCADE,
  texto_opcao TEXT NOT NULL,
  votos_count INTEGER NOT NULL DEFAULT 0,
  ordem INTEGER NOT NULL DEFAULT 1,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comunidade_enquete_opcoes_post ON public.comunidade_enquete_opcoes(post_id, ordem);

-- ============================================================================
-- 7. TABELA: comunidade_enquete_votos (Voto único por aluno em cada enquete)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_enquete_votos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.comunidade_posts(id) ON DELETE CASCADE,
  opcao_id UUID NOT NULL REFERENCES public.comunidade_enquete_opcoes(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_comunidade_enquete_votos_post ON public.comunidade_enquete_votos(post_id);

-- ============================================================================
-- 8. TABELA: comunidade_salas_estudo (Salas de Estudo Ao Vivo — Pomodoro)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_salas_estudo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  nome TEXT NOT NULL, -- Ex: 'Sala PF — Foco Total', 'Sala Receita & TJSP'
  descricao TEXT DEFAULT 'Estude em silêncio com áudio ambiente e câmera voluntária.',
  concurso_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  ciclo_pomodoro_minutos INTEGER NOT NULL DEFAULT 50,
  pausa_minutos INTEGER NOT NULL DEFAULT 10,
  capacidade_maxima INTEGER NOT NULL DEFAULT 100,
  participantes_online_base INTEGER NOT NULL DEFAULT 0,
  ativa BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_comunidade_salas_updated_at ON public.comunidade_salas_estudo;
CREATE TRIGGER trg_comunidade_salas_updated_at
BEFORE UPDATE ON public.comunidade_salas_estudo
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 9. TABELA: comunidade_sala_presenca (Alunos presentes nas salas Pomodoro)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_sala_presenca (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sala_id UUID NOT NULL REFERENCES public.comunidade_salas_estudo(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'focado'
    CHECK (status IN ('focado', 'pausa', 'offline')),
  camera_ativa BOOLEAN NOT NULL DEFAULT false,
  entrou_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ultimo_ping_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (sala_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_comunidade_sala_presenca_sala ON public.comunidade_sala_presenca(sala_id, status);

-- ============================================================================
-- 10. TABELA: comunidade_denuncias (Moderação de posts e comentários)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comunidade_denuncias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  denunciante_user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.comunidade_posts(id) ON DELETE CASCADE,
  comentario_id UUID REFERENCES public.comunidade_comentarios(id) ON DELETE CASCADE,
  motivo TEXT NOT NULL DEFAULT 'spam'
    CHECK (motivo IN ('spam', 'conteudo_ofensivo', 'informacao_incorreta', 'plagio_direitos', 'outro')),
  detalhes TEXT,
  status TEXT NOT NULL DEFAULT 'pendente'
    CHECK (status IN ('pendente', 'em_analise', 'resolvida', 'arquivada')),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comunidade_denuncias_status ON public.comunidade_denuncias(status, criado_em DESC);
