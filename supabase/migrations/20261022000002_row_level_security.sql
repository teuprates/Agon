-- ==============================================================================
-- AGON - PLATAFORMA DE ESTUDOS INTELIGENTE
-- MIGRATION: 20261022000002_row_level_security.sql
-- Descrição: Configuração de Row Level Security (RLS) e Políticas de Acesso
-- ==============================================================================

-- 1. HABILITAR RLS EM TODAS AS TABELAS
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_topic_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_recommendations ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 2. POLÍTICAS: usuarios
-- Cada estudante só pode consultar e editar seu próprio perfil
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Usuários podem visualizar o próprio perfil" ON public.usuarios;
CREATE POLICY "Usuários podem visualizar o próprio perfil"
    ON public.usuarios
    FOR SELECT
    USING (auth.uid()::text = id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Usuários podem atualizar o próprio perfil" ON public.usuarios;
CREATE POLICY "Usuários podem atualizar o próprio perfil"
    ON public.usuarios
    FOR UPDATE
    USING (auth.uid()::text = id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Inserção de perfil no cadastro" ON public.usuarios;
CREATE POLICY "Inserção de perfil no cadastro"
    ON public.usuarios
    FOR INSERT
    WITH CHECK (auth.uid()::text = id OR auth.role() = 'service_role' OR auth.role() = 'anon');

-- ------------------------------------------------------------------------------
-- 3. POLÍTICAS: question_attempts
-- Cada estudante só pode ler e registrar suas próprias tentativas
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Estudantes podem visualizar suas tentativas" ON public.question_attempts;
CREATE POLICY "Estudantes podem visualizar suas tentativas"
    ON public.question_attempts
    FOR SELECT
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Estudantes podem inserir suas tentativas" ON public.question_attempts;
CREATE POLICY "Estudantes podem inserir suas tentativas"
    ON public.question_attempts
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- ------------------------------------------------------------------------------
-- 4. POLÍTICAS: student_topic_stats
-- Estatísticas isoladas estritamente por estudante
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Estudantes podem visualizar suas estatísticas" ON public.student_topic_stats;
CREATE POLICY "Estudantes podem visualizar suas estatísticas"
    ON public.student_topic_stats
    FOR SELECT
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Estudantes podem registrar suas estatísticas" ON public.student_topic_stats;
CREATE POLICY "Estudantes podem registrar suas estatísticas"
    ON public.student_topic_stats
    FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- ------------------------------------------------------------------------------
-- 5. POLÍTICAS: ai_conversations
-- Conversas com a Zuka IA são privadas de cada estudante
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Estudantes acessam apenas suas conversas" ON public.ai_conversations;
CREATE POLICY "Estudantes acessam apenas suas conversas"
    ON public.ai_conversations
    FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- ------------------------------------------------------------------------------
-- 6. POLÍTICAS: ai_messages
-- Mensagens do chat privadas do autor da conversa
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Estudantes acessam apenas suas mensagens" ON public.ai_messages;
CREATE POLICY "Estudantes acessam apenas suas mensagens"
    ON public.ai_messages
    FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- ------------------------------------------------------------------------------
-- 7. POLÍTICAS: study_recommendations
-- Recomendações e plano de estudos do estudante
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Estudantes acessam apenas suas recomendações" ON public.study_recommendations;
CREATE POLICY "Estudantes acessam apenas suas recomendações"
    ON public.study_recommendations
    FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');
