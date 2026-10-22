-- ============================================================================
-- AGON — Migração 013: Row Level Security (RLS) Completa & Sincronização Auth
-- ============================================================================
-- Descrição: Habilita Row Level Security (RLS) em TODAS as novas tabelas e cria
-- políticas idempotentes (`DROP POLICY IF EXISTS` + `CREATE POLICY`) divididas em:
-- 1. Catálogo Público / Autenticado (Somente leitura para clientes; escrita via service_role)
-- 2. Dados Privados do Aluno (`auth.uid()::text = user_id`)
-- 3. Comunidade & Fóruns (Leitura para autenticados; escrita/edição pelo próprio autor)
-- 4. Trigger opcional de sincronização `auth.users` -> `public.usuarios`
-- ============================================================================

-- ============================================================================
-- 1. HABILITAR RLS EM TODAS AS TABELAS NOVAS
-- ============================================================================
ALTER TABLE public.bancas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concursos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assuntos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concurso_disciplina_pesos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edital_topicos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.questoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questao_alternativas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questao_comentarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questao_favoritos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questao_anotacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cadernos_questoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caderno_questoes_itens ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aulas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aula_anexos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aula_progresso ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aula_anotacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aula_perguntas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aula_respostas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materiais ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_interacoes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.simulados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.simulado_questoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.simulado_tentativas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.simulado_respostas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.aluno_concursos_acompanhados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planos_estudo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma_tarefas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aluno_edital_progresso ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revisoes_espacadas_sm2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caderno_erros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.niveis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temporadas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conquistas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aluno_conquistas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dias_estudo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.atividades_recentes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.comunidade_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_post_hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_comentarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_curtidas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_favoritos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_enquete_opcoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_enquete_votos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_salas_estudo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_sala_presenca ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comunidade_denuncias ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.usuario_preferencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tokens_redefinicao_senha ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessoes_usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tentativas_login ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aceites_termos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planos_assinatura ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assinaturas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faturas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.roadmap_fases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roadmap_modulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lista_espera_modulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sugestoes_produto ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.depoimentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_generation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_rate_limits ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. POLÍTICAS DE CATÁLOGO (Leitura pública/autenticada; escrita via service_role)
-- ============================================================================
DO $$
DECLARE
  t TEXT;
  catalog_tables TEXT[] := ARRAY[
    'bancas', 'concursos', 'disciplinas', 'assuntos', 'concurso_disciplina_pesos',
    'edital_topicos', 'questoes', 'questao_alternativas', 'cursos', 'modulos',
    'aulas', 'aula_anexos', 'materiais', 'simulados', 'simulado_questoes',
    'niveis', 'temporadas', 'conquistas', 'comunidade_salas_estudo',
    'planos_assinatura', 'roadmap_fases', 'roadmap_modulos', 'depoimentos'
  ];
BEGIN
  FOREACH t IN ARRAY catalog_tables LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_public', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT USING (true)',
      t || '_select_public', t
    );
  END LOOP;
END $$;

-- ============================================================================
-- 3. POLÍTICAS DE DADOS PRIVADOS DO ALUNO (`auth.uid()::text = user_id`)
-- ============================================================================
DO $$
DECLARE
  t TEXT;
  private_user_tables TEXT[] := ARRAY[
    'questao_favoritos', 'questao_anotacoes', 'cadernos_questoes',
    'aula_progresso', 'aula_anotacoes', 'certificados', 'material_interacoes',
    'simulado_tentativas', 'aluno_concursos_acompanhados', 'planos_estudo',
    'cronograma_tarefas', 'aluno_edital_progresso', 'revisoes_espacadas_sm2',
    'caderno_erros', 'aluno_conquistas', 'xp_ledger', 'dias_estudo',
    'atividades_recentes', 'usuario_preferencias', 'notificacoes',
    'sessoes_usuario', 'aceites_termos', 'assinaturas', 'faturas',
    'ai_generation_logs', 'ai_rate_limits'
  ];
BEGIN
  FOREACH t IN ARRAY private_user_tables LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_own', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT USING (auth.uid()::text = user_id)',
      t || '_select_own', t
    );

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_insert_own', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR INSERT WITH CHECK (auth.uid()::text = user_id)',
      t || '_insert_own', t
    );

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_update_own', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR UPDATE USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id)',
      t || '_update_own', t
    );

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_delete_own', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR DELETE USING (auth.uid()::text = user_id)',
      t || '_delete_own', t
    );
  END LOOP;
END $$;

-- Tabelas filhas vinculadas por chave estrangeira do pai (caderno_questoes_itens e simulado_respostas)
DROP POLICY IF EXISTS caderno_itens_own ON public.caderno_questoes_itens;
CREATE POLICY caderno_itens_own ON public.caderno_questoes_itens
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.cadernos_questoes c
    WHERE c.id = caderno_id AND c.user_id = auth.uid()::text
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.cadernos_questoes c
    WHERE c.id = caderno_id AND c.user_id = auth.uid()::text
  )
);

DROP POLICY IF EXISTS simulado_respostas_own ON public.simulado_respostas;
CREATE POLICY simulado_respostas_own ON public.simulado_respostas
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.simulado_tentativas st
    WHERE st.id = tentativa_id AND st.user_id = auth.uid()::text
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.simulado_tentativas st
    WHERE st.id = tentativa_id AND st.user_id = auth.uid()::text
  )
);

-- Flashcards: leitura de flashcards oficiais ou próprios; escrita apenas nos próprios
DROP POLICY IF EXISTS flashcards_select_policy ON public.flashcards;
CREATE POLICY flashcards_select_policy ON public.flashcards
FOR SELECT USING (oficial_agon = true OR auth.uid()::text = user_id);

DROP POLICY IF EXISTS flashcards_write_own ON public.flashcards;
CREATE POLICY flashcards_write_own ON public.flashcards
FOR ALL
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- ============================================================================
-- 4. POLÍTICAS DA COMUNIDADE E FÓRUNS DE AULA / QUESTÃO
-- ============================================================================
-- Leitura aberta para todos os alunos autenticados; criação/edição apenas pelo autor
DROP POLICY IF EXISTS comunidade_posts_select_all ON public.comunidade_posts;
CREATE POLICY comunidade_posts_select_all ON public.comunidade_posts
FOR SELECT USING (status_moderacao = 'ativo' OR auth.uid()::text = user_id);

DROP POLICY IF EXISTS comunidade_posts_insert_own ON public.comunidade_posts;
CREATE POLICY comunidade_posts_insert_own ON public.comunidade_posts
FOR INSERT WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS comunidade_posts_update_own ON public.comunidade_posts;
CREATE POLICY comunidade_posts_update_own ON public.comunidade_posts
FOR UPDATE USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS comunidade_posts_delete_own ON public.comunidade_posts;
CREATE POLICY comunidade_posts_delete_own ON public.comunidade_posts
FOR DELETE USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS comunidade_hashtags_select_all ON public.comunidade_post_hashtags;
CREATE POLICY comunidade_hashtags_select_all ON public.comunidade_post_hashtags
FOR SELECT USING (true);

DROP POLICY IF EXISTS comunidade_enquete_opcoes_select_all ON public.comunidade_enquete_opcoes;
CREATE POLICY comunidade_enquete_opcoes_select_all ON public.comunidade_enquete_opcoes
FOR SELECT USING (true);

DO $$
DECLARE
  t TEXT;
  social_tables TEXT[] := ARRAY[
    'comunidade_comentarios', 'comunidade_curtidas', 'comunidade_favoritos',
    'comunidade_enquete_votos', 'comunidade_sala_presenca',
    'questao_comentarios', 'aula_perguntas'
  ];
BEGIN
  FOREACH t IN ARRAY social_tables LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select_all', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (true)', t || '_select_all', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_insert_own', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR INSERT WITH CHECK (auth.uid()::text = user_id)', t || '_insert_own', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_update_own', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR UPDATE USING (auth.uid()::text = user_id)', t || '_update_own', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_delete_own', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE USING (auth.uid()::text = user_id)', t || '_delete_own', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS aula_respostas_select_all ON public.aula_respostas;
CREATE POLICY aula_respostas_select_all ON public.aula_respostas
FOR SELECT USING (true);

DROP POLICY IF EXISTS comunidade_denuncias_insert_own ON public.comunidade_denuncias;
CREATE POLICY comunidade_denuncias_insert_own ON public.comunidade_denuncias
FOR INSERT WITH CHECK (auth.uid()::text = denunciante_user_id);

DROP POLICY IF EXISTS lista_espera_insert_public ON public.lista_espera_modulos;
CREATE POLICY lista_espera_insert_public ON public.lista_espera_modulos
FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS sugestoes_produto_insert_auth ON public.sugestoes_produto;
CREATE POLICY sugestoes_produto_insert_auth ON public.sugestoes_produto
FOR INSERT WITH CHECK (user_id IS NULL OR auth.uid()::text = user_id);

DROP POLICY IF EXISTS sugestoes_produto_select_own ON public.sugestoes_produto;
CREATE POLICY sugestoes_produto_select_own ON public.sugestoes_produto
FOR SELECT USING (auth.uid()::text = user_id);

-- ============================================================================
-- 5. TRIGGER OPCIONAL PARA SINCRONIZAR `auth.users` -> `public.usuarios`
-- ============================================================================
-- Permite transição suave para Supabase Auth mantendo compatibilidade total com
-- o fluxo atual (`express-session` + `service_role`).
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.usuarios (
    id,
    auth_user_id,
    nome,
    email,
    senha,
    telefone,
    tipo_usuario,
    tipo_assinatura,
    pontos_gamificacao
  )
  VALUES (
    NEW.id::text,
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nome', split_part(NEW.email, '@', 1)),
    NEW.email,
    'supabase_auth_managed',
    COALESCE(NEW.raw_user_meta_data->>'telefone', ''),
    'aluno',
    'gratuito',
    0
  )
  ON CONFLICT (email) DO UPDATE SET
    auth_user_id = EXCLUDED.auth_user_id,
    atualizado_em = NOW();

  INSERT INTO public.usuario_preferencias (user_id)
  VALUES (NEW.id::text)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;
