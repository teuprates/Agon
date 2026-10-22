-- ==============================================================================
-- AGON - PLATAFORMA DE ESTUDOS INTELIGENTE
-- MIGRATION: 20261022000001_initial_schema.sql
-- Descrição: Criação da estrutura de tabelas, tipos, restrições e índices
-- ==============================================================================

-- 1. Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Função utilitária para atualizar automaticamente o campo atualizado_em
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 2. TABELA: usuarios (Perfis e Dados dos Estudantes)
-- Vinculada opcionalmente ao auth.users do Supabase Auth ou identificador único
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuarios (
    id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    senha TEXT, -- Hash bcrypt para autenticação direta quando aplicável
    telefone TEXT,
    tipo_usuario TEXT NOT NULL DEFAULT 'aluno' CHECK (tipo_usuario IN ('aluno', 'professor', 'administrador')),
    tipo_assinatura TEXT NOT NULL DEFAULT 'gratuito' CHECK (tipo_assinatura IN ('gratuito', 'premium', 'elite')),
    pontos_gamificacao INTEGER NOT NULL DEFAULT 0 CHECK (pontos_gamificacao >= 0),
    avatar_url TEXT,
    concurso_alvo TEXT DEFAULT 'Geral',
    horas_semanais INTEGER DEFAULT 15,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_usuarios_email ON public.usuarios (LOWER(email));

DROP TRIGGER IF EXISTS trg_usuarios_updated_at ON public.usuarios;
CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON public.usuarios
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 3. TABELA: question_attempts (Histórico de Questões Resolvidas)
-- Registra cada tentativa do estudante para personalização e métricas
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.question_attempts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    question_id TEXT NOT NULL,
    disciplina TEXT NOT NULL,
    assunto TEXT NOT NULL,
    subassunto TEXT DEFAULT '',
    resposta_selecionada TEXT NOT NULL,
    resposta_correta TEXT NOT NULL,
    acertou BOOLEAN NOT NULL,
    tempo_gasto_segundos INTEGER NOT NULL DEFAULT 0 CHECK (tempo_gasto_segundos >= 0),
    origem TEXT NOT NULL DEFAULT 'oficial' CHECK (origem IN ('oficial', 'cadastrada', 'ia_gerada')),
    banca TEXT DEFAULT '',
    ano TEXT DEFAULT '',
    tentativa_num INTEGER NOT NULL DEFAULT 1 CHECK (tentativa_num >= 1),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attempts_user_id ON public.question_attempts (user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_user_question ON public.question_attempts (user_id, question_id);
CREATE INDEX IF NOT EXISTS idx_attempts_user_disc_assunto ON public.question_attempts (user_id, disciplina, assunto);
CREATE INDEX IF NOT EXISTS idx_attempts_criado_em ON public.question_attempts (criado_em DESC);

-- ------------------------------------------------------------------------------
-- 4. TABELA: student_topic_stats (Estatísticas Agregadas por Estudante e Assunto)
-- Utilizada pelo dashboard e pela Zuka IA para o Mapa de Dificuldades
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_topic_stats (
    id TEXT PRIMARY KEY, -- Formato: ${userId}_${disciplina}_${assunto}
    user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    disciplina TEXT NOT NULL,
    assunto TEXT NOT NULL,
    total_respondidas INTEGER NOT NULL DEFAULT 0 CHECK (total_respondidas >= 0),
    total_acertos INTEGER NOT NULL DEFAULT 0 CHECK (total_acertos >= 0),
    total_erros INTEGER NOT NULL DEFAULT 0 CHECK (total_erros >= 0),
    tempo_total_segundos INTEGER NOT NULL DEFAULT 0 CHECK (tempo_total_segundos >= 0),
    taxa_acerto INTEGER NOT NULL DEFAULT 0 CHECK (taxa_acerto BETWEEN 0 AND 100),
    taxa_erro INTEGER NOT NULL DEFAULT 0 CHECK (taxa_erro BETWEEN 0 AND 100),
    classificacao_dificuldade TEXT NOT NULL DEFAULT 'dados_insuficientes' 
        CHECK (classificacao_dificuldade IN ('alta', 'moderada', 'em_desenvolvimento', 'dados_insuficientes')),
    ultima_atividade TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_topic_stats_user ON public.student_topic_stats (user_id);
CREATE INDEX IF NOT EXISTS idx_topic_stats_diff ON public.student_topic_stats (user_id, classificacao_dificuldade);

-- ------------------------------------------------------------------------------
-- 5. TABELA: ai_conversations (Conversas com a Zuka IA)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_user ON public.ai_conversations (user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON public.ai_conversations (user_id, atualizado_em DESC);

DROP TRIGGER IF EXISTS trg_conversations_updated_at ON public.ai_conversations;
CREATE TRIGGER trg_conversations_updated_at
    BEFORE UPDATE ON public.ai_conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 6. TABELA: ai_messages (Mensagens do Chat com a Zuka IA)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'model', 'assistant')),
    conteudo TEXT NOT NULL,
    contexto_questao JSONB,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.ai_messages (conversation_id, criado_em ASC);
CREATE INDEX IF NOT EXISTS idx_messages_user ON public.ai_messages (user_id);

-- ------------------------------------------------------------------------------
-- 7. TABELA: study_recommendations (Plano de Estudos e Recomendações da Zuka IA)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.study_recommendations (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    descricao TEXT NOT NULL,
    disciplina TEXT NOT NULL DEFAULT 'Geral',
    assunto TEXT NOT NULL DEFAULT 'Geral',
    prioridade TEXT NOT NULL DEFAULT 'media' CHECK (prioridade IN ('alta', 'media', 'baixa')),
    tipo TEXT NOT NULL DEFAULT 'revisao' CHECK (tipo IN ('revisao', 'fixacao', 'expansao')),
    status TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'em_andamento', 'concluido')),
    gerado_por TEXT NOT NULL DEFAULT 'regras_estatisticas',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recommendations_user ON public.study_recommendations (user_id, status);

DROP TRIGGER IF EXISTS trg_recommendations_updated_at ON public.study_recommendations;
CREATE TRIGGER trg_recommendations_updated_at
    BEFORE UPDATE ON public.study_recommendations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
