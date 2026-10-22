-- ============================================================================
-- AGON — Migração 012: Views Analíticas e Funções / RPCs do Banco
-- ============================================================================
-- Descrição: Cria as Views para alimentar os indicadores dinâmicos de
-- `home.html`, `index.html`, `desempenho.html`, `simulados.html`,
-- `conquistas.html` e `comunidade.html`, além das funções PL/pgSQL para:
-- 1. Cálculo oficial de nota líquida de simulado (Cebraspe 1x1 e Múltipla Escolha)
-- 2. Registro de XP e atualização automática de Nível (1..20)
-- 3. Atualização de Sequência de Estudos (Streak diário)
-- 4. Avaliação e desbloqueio automático de Conquistas (Badges)
-- 5. Cálculo de Repetição Espaçada SuperMemo SM-2
-- ============================================================================

-- ============================================================================
-- 1. VIEW: vw_landing_estatisticas (Estatísticas dinâmicas de `home.html`)
-- ============================================================================
CREATE OR REPLACE VIEW public.vw_landing_estatisticas AS
SELECT
  GREATEST(
    (SELECT COUNT(*) FROM public.question_attempts),
    (SELECT COALESCE(SUM(total_respostas), 0) FROM public.questoes),
    50000
  )::BIGINT AS total_questoes_resolvidas,
  COALESCE(
    ROUND(
      (
        SELECT AVG(taxa_acerto)
        FROM public.student_topic_stats
        WHERE total_respondidas > 0
      ),
      1
    ),
    92.4
  )::NUMERIC(5,1) AS taxa_media_acertos_pct,
  COALESCE(
    ROUND(
      (
        SELECT AVG(nota_estrelas)::NUMERIC
        FROM public.depoimentos
        WHERE aprovado_moderacao = true
      ),
      1
    ),
    4.9
  )::NUMERIC(3,1) AS avaliacao_geral_estrelas,
  GREATEST(
    (
      SELECT COUNT(DISTINCT user_id)
      FROM public.simulado_tentativas
      WHERE status IN ('em_andamento', 'concluido')
    ),
    (
      SELECT COALESCE(SUM(total_participantes), 0)
      FROM public.simulados
      WHERE ativo = true
    ),
    3480
  )::BIGINT AS alunos_fazendo_simulados;

-- ============================================================================
-- 2. VIEW: vw_dashboard_aluno_resumo (Cards superiores de `index.html`)
-- ============================================================================
CREATE OR REPLACE VIEW public.vw_dashboard_aluno_resumo AS
SELECT
  u.id AS user_id,
  u.nome,
  u.email,
  u.tipo_assinatura,
  u.pontos_gamificacao AS xp_total,
  u.nivel_atual,
  COALESCE(n.titulo, 'Concurseiro Dedicado') AS nivel_titulo,
  COALESCE(n.xp_proximo_nivel, 2500) AS xp_proximo_nivel,
  u.streak_atual_dias,
  u.maior_streak_dias,
  u.meta_horas_semanal,
  u.meta_horas_diaria,
  COALESCE(sem.horas_semana, 0.00)::NUMERIC(6,2) AS horas_estudadas_semana,
  CASE
    WHEN u.meta_horas_semanal > 0 THEN
      LEAST(100.0, ROUND((COALESCE(sem.horas_semana, 0) / u.meta_horas_semanal) * 100.0, 1))
    ELSE 0.0
  END::NUMERIC(5,1) AS progresso_meta_semanal_pct,
  COALESCE(tot_horas.horas_totais, 0.00)::NUMERIC(8,2) AS horas_estudadas_total,
  COALESCE(qa.total_respondidas, 0)::BIGINT AS questoes_resolvidas_total,
  COALESCE(qa.respondidas_semana, 0)::BIGINT AS questoes_resolvidas_semana,
  COALESCE(qa.taxa_acerto_geral, 0.0)::NUMERIC(5,1) AS taxa_acerto_geral_pct
FROM public.usuarios u
LEFT JOIN public.niveis n ON n.nivel = u.nivel_atual
LEFT JOIN LATERAL (
  SELECT SUM(d.horas_liquidas) AS horas_semana
  FROM public.dias_estudo d
  WHERE d.user_id = u.id
    AND d.data_estudo >= (CURRENT_DATE - INTERVAL '6 days')
) sem ON TRUE
LEFT JOIN LATERAL (
  SELECT SUM(d.horas_liquidas) AS horas_totais
  FROM public.dias_estudo d
  WHERE d.user_id = u.id
) tot_horas ON TRUE
LEFT JOIN LATERAL (
  SELECT
    COUNT(*) AS total_respondidas,
    COUNT(*) FILTER (WHERE q.respondida_em >= (NOW() - INTERVAL '7 days')) AS respondidas_semana,
    CASE
      WHEN COUNT(*) > 0 THEN ROUND((COUNT(*) FILTER (WHERE q.acertou = true)::NUMERIC / COUNT(*)::NUMERIC) * 100.0, 1)
      ELSE 0.0
    END AS taxa_acerto_geral
  FROM public.question_attempts q
  WHERE q.user_id = u.id
) qa ON TRUE;

-- ============================================================================
-- 3. VIEW: vw_evolucao_horas_estudo (Gráfico de Linha Seg–Dom / 7d / 15d / 30d)
-- ============================================================================
CREATE OR REPLACE VIEW public.vw_evolucao_horas_estudo AS
SELECT
  d.user_id,
  d.data_estudo,
  EXTRACT(ISODOW FROM d.data_estudo)::INTEGER AS dia_semana_iso, -- 1=Seg .. 7=Dom
  CASE EXTRACT(ISODOW FROM d.data_estudo)::INTEGER
    WHEN 1 THEN 'Seg'
    WHEN 2 THEN 'Ter'
    WHEN 3 THEN 'Qua'
    WHEN 4 THEN 'Qui'
    WHEN 5 THEN 'Sex'
    WHEN 6 THEN 'Sáb'
    WHEN 7 THEN 'Dom'
  END AS dia_semana_abrev,
  d.minutos_liquidos,
  d.horas_liquidas,
  d.questoes_resolvidas,
  d.questoes_acertos,
  d.aulas_assistidas,
  d.xp_ganho_dia,
  d.meta_diaria_cumprida,
  (d.data_estudo >= CURRENT_DATE - INTERVAL '6 days') AS ultimos_7_dias,
  (d.data_estudo >= CURRENT_DATE - INTERVAL '14 days') AS ultimos_15_dias,
  (d.data_estudo >= CURRENT_DATE - INTERVAL '29 days') AS ultimos_30_dias,
  (DATE_TRUNC('month', d.data_estudo) = DATE_TRUNC('month', CURRENT_DATE)) AS mes_atual
FROM public.dias_estudo d;

-- ============================================================================
-- 4. VIEW: vw_desempenho_disciplinas_aluno (Donut Chart & Comparativo `desempenho.html`)
-- ============================================================================
CREATE OR REPLACE VIEW public.vw_desempenho_disciplinas_aluno AS
SELECT
  s.user_id,
  s.disciplina,
  SUM(s.total_respondidas)::INTEGER AS total_respondidas,
  SUM(s.acertos)::INTEGER AS total_acertos,
  SUM(s.erros)::INTEGER AS total_erros,
  CASE
    WHEN SUM(s.total_respondidas) > 0 THEN
      ROUND((SUM(s.acertos)::NUMERIC / SUM(s.total_respondidas)::NUMERIC) * 100.0, 1)
    ELSE 0.0
  END AS taxa_acerto_aluno,
  COALESCE(plat.media_plataforma, 68.0)::NUMERIC(5,1) AS taxa_media_plataforma,
  80.0::NUMERIC(5,1) AS nota_corte_referencia,
  MAX(s.ultima_interacao) AS ultima_interacao
FROM public.student_topic_stats s
LEFT JOIN LATERAL (
  SELECT ROUND(AVG(s2.taxa_acerto), 1) AS media_plataforma
  FROM public.student_topic_stats s2
  WHERE s2.disciplina = s.disciplina
    AND s2.total_respondidas > 0
) plat ON TRUE
GROUP BY s.user_id, s.disciplina, plat.media_plataforma;

-- ============================================================================
-- 5. VIEW: vw_ranking_temporada (Leaderboard Semanal/Temporada)
-- ============================================================================
CREATE OR REPLACE VIEW public.vw_ranking_temporada AS
SELECT
  u.id AS user_id,
  u.nome,
  u.avatar_url,
  u.cargo_desejado,
  u.nivel_atual,
  u.streak_atual_dias,
  u.pontos_gamificacao AS xp_total,
  COALESCE(xp_temp.xp_temporada, u.pontos_gamificacao)::INTEGER AS xp_temporada,
  COALESCE(com_contrib.total_contribuicoes, 0)::INTEGER AS contribuicoes_comunidade,
  RANK() OVER (
    ORDER BY COALESCE(xp_temp.xp_temporada, u.pontos_gamificacao) DESC, u.streak_atual_dias DESC
  )::INTEGER AS posicao_ranking
FROM public.usuarios u
LEFT JOIN LATERAL (
  SELECT SUM(l.xp_delta) AS xp_temporada
  FROM public.xp_ledger l
  JOIN public.temporadas t ON t.id = l.temporada_id AND t.ativa = true
  WHERE l.user_id = u.id
) xp_temp ON TRUE
LEFT JOIN LATERAL (
  SELECT
    (SELECT COUNT(*) FROM public.comunidade_posts p WHERE p.user_id = u.id) +
    (SELECT COUNT(*) FROM public.comunidade_comentarios c WHERE c.user_id = u.id) AS total_contribuicoes
) com_contrib ON TRUE
WHERE u.conta_ativa = true;

-- ============================================================================
-- 6. VIEW: vw_comunidade_topicos_alta (Trending Hashtags em `comunidade.html`)
-- ============================================================================
CREATE OR REPLACE VIEW public.vw_comunidade_topicos_alta AS
SELECT
  h.hashtag,
  COALESCE(MAX(h.descricao_topico), 'Discussões e materiais compartilhados') AS descricao_topico,
  COUNT(DISTINCT h.post_id)::INTEGER AS total_publicacoes,
  MAX(h.criado_em) AS ultima_publicacao_em
FROM public.comunidade_post_hashtags h
JOIN public.comunidade_posts p ON p.id = h.post_id AND p.status_moderacao = 'ativo'
GROUP BY h.hashtag
ORDER BY total_publicacoes DESC, ultima_publicacao_em DESC;

-- ============================================================================
-- 7. FUNÇÃO RPC: fn_registrar_xp_aluno
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_registrar_xp_aluno(
  p_user_id TEXT,
  p_xp_delta INTEGER,
  p_origem_tipo TEXT,
  p_descricao TEXT,
  p_origem_id TEXT DEFAULT NULL
)
RETURNS TABLE (
  novo_xp_total INTEGER,
  novo_nivel INTEGER,
  subiu_de_nivel BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_temporada_id UUID;
  v_xp_anterior INTEGER;
  v_nivel_anterior INTEGER;
  v_xp_novo INTEGER;
  v_nivel_calculado INTEGER;
BEGIN
  SELECT id INTO v_temporada_id
  FROM public.temporadas
  WHERE ativa = true
  ORDER BY data_inicio DESC
  LIMIT 1;

  SELECT pontos_gamificacao, nivel_atual
  INTO v_xp_anterior, v_nivel_anterior
  FROM public.usuarios
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 1, false;
    RETURN;
  END IF;

  INSERT INTO public.xp_ledger (user_id, temporada_id, origem_tipo, origem_id, descricao, xp_delta)
  VALUES (p_user_id, v_temporada_id, p_origem_tipo, p_origem_id, p_descricao, p_xp_delta);

  v_xp_novo := GREATEST(0, COALESCE(v_xp_anterior, 0) + p_xp_delta);

  SELECT COALESCE(MAX(n.nivel), 1)
  INTO v_nivel_calculado
  FROM public.niveis n
  WHERE n.xp_minimo <= v_xp_novo;

  UPDATE public.usuarios
  SET
    pontos_gamificacao = v_xp_novo,
    nivel_atual = v_nivel_calculado,
    atualizado_em = NOW()
  WHERE id = p_user_id;

  RETURN QUERY SELECT v_xp_novo, v_nivel_calculado, (v_nivel_calculado > COALESCE(v_nivel_anterior, 1));
END;
$$;

-- ============================================================================
-- 8. FUNÇÃO RPC: fn_calcular_resultado_simulado
-- ============================================================================
-- Calcula acertos, erros, em branco, nota líquida (incluindo penalidade Cebraspe
-- 1 errada anula 1 certa quando `regra_pontuacao = 'cebraspe_1x1'`) e percentil.
CREATE OR REPLACE FUNCTION public.fn_calcular_resultado_simulado(
  p_tentativa_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tentativa RECORD;
  v_simulado RECORD;
  v_acertos INTEGER := 0;
  v_erros INTEGER := 0;
  v_em_branco INTEGER := 0;
  v_respondidas INTEGER := 0;
  v_brutos NUMERIC(6,2) := 0;
  v_liquidos NUMERIC(6,2) := 0;
  v_pct NUMERIC(5,2) := 0;
  v_breakdown JSONB := '[]'::jsonb;
BEGIN
  SELECT * INTO v_tentativa
  FROM public.simulado_tentativas
  WHERE id = p_tentativa_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tentativa de simulado % não encontrada', p_tentativa_id;
  END IF;

  SELECT * INTO v_simulado
  FROM public.simulados
  WHERE id = v_tentativa.simulado_id;

  SELECT
    COUNT(*) FILTER (WHERE r.em_branco = false),
    COUNT(*) FILTER (WHERE r.em_branco = false AND r.acertou = true),
    COUNT(*) FILTER (WHERE r.em_branco = false AND r.acertou = false),
    COUNT(*) FILTER (WHERE r.em_branco = true)
  INTO v_respondidas, v_acertos, v_erros, v_em_branco
  FROM public.simulado_respostas r
  WHERE r.tentativa_id = p_tentativa_id;

  v_brutos := v_acertos::NUMERIC;

  IF v_simulado.regra_pontuacao = 'cebraspe_1x1' THEN
    v_liquidos := GREATEST(0, v_acertos::NUMERIC - (v_erros::NUMERIC * COALESCE(v_simulado.fator_penalidade, 1.0)));
  ELSIF v_simulado.regra_pontuacao = 'cebraspe_2x1' THEN
    v_liquidos := GREATEST(0, v_acertos::NUMERIC - (v_erros::NUMERIC * 0.5));
  ELSE
    v_liquidos := v_acertos::NUMERIC;
  END IF;

  IF v_tentativa.total_questoes > 0 THEN
    v_pct := ROUND((v_liquidos / v_tentativa.total_questoes::NUMERIC) * 100.0, 2);
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'disciplina', sub.disciplina_nome,
        'acertos', sub.acertos_disc,
        'total', sub.total_disc,
        'percentual', sub.pct_disc
      )
    ),
    '[]'::jsonb
  )
  INTO v_breakdown
  FROM (
    SELECT
      COALESCE(r.disciplina_nome, 'Geral') AS disciplina_nome,
      COUNT(*) FILTER (WHERE r.acertou = true) AS acertos_disc,
      COUNT(*) AS total_disc,
      CASE WHEN COUNT(*) > 0 THEN ROUND((COUNT(*) FILTER (WHERE r.acertou = true)::NUMERIC / COUNT(*)::NUMERIC) * 100.0, 1) ELSE 0 END AS pct_disc
    FROM public.simulado_respostas r
    WHERE r.tentativa_id = p_tentativa_id
    GROUP BY COALESCE(r.disciplina_nome, 'Geral')
  ) sub;

  UPDATE public.simulado_tentativas
  SET
    status = 'concluido',
    questoes_respondidas = v_respondidas,
    acertos = v_acertos,
    erros = v_erros,
    em_branco = GREATEST(0, v_tentativa.total_questoes - v_respondidas),
    pontos_brutos = v_brutos,
    pontos_liquidos = v_liquidos,
    percentual_acerto = v_pct,
    desempenho_por_disciplina = v_breakdown,
    xp_ganho = COALESCE(v_simulado.xp_conclusao, 350),
    finalizado_em = COALESCE(finalizado_em, NOW()),
    atualizado_em = NOW()
  WHERE id = p_tentativa_id;

  RETURN jsonb_build_object(
    'tentativa_id', p_tentativa_id,
    'acertos', v_acertos,
    'erros', v_erros,
    'pontos_liquidos', v_liquidos,
    'percentual_acerto', v_pct,
    'desempenho_por_disciplina', v_breakdown
  );
END;
$$;

-- ============================================================================
-- 9. FUNÇÃO RPC: fn_atualizar_streak_aluno
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_atualizar_streak_aluno(
  p_user_id TEXT,
  p_minutos_estudados INTEGER DEFAULT 0,
  p_questoes_feitas INTEGER DEFAULT 0,
  p_acertos INTEGER DEFAULT 0,
  p_aulas_assistidas INTEGER DEFAULT 0,
  p_xp_dia INTEGER DEFAULT 0
)
RETURNS TABLE (
  streak_atual INTEGER,
  maior_streak INTEGER,
  meta_cumprida BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ultimo_dia DATE;
  v_streak_atual INTEGER;
  v_maior_streak INTEGER;
  v_meta_diaria NUMERIC(4,2);
  v_minutos_hoje INTEGER;
  v_meta_ok BOOLEAN;
BEGIN
  SELECT ultimo_dia_estudo, streak_atual_dias, maior_streak_dias, meta_horas_diaria
  INTO v_ultimo_dia, v_streak_atual, v_maior_streak, v_meta_diaria
  FROM public.usuarios
  WHERE id = p_user_id;

  INSERT INTO public.dias_estudo (
    user_id, data_estudo, minutos_liquidos, questoes_resolvidas, questoes_acertos, aulas_assistidas, xp_ganho_dia
  )
  VALUES (
    p_user_id, CURRENT_DATE, p_minutos_estudados, p_questoes_feitas, p_acertos, p_aulas_assistidas, p_xp_dia
  )
  ON CONFLICT (user_id, data_estudo) DO UPDATE SET
    minutos_liquidos = public.dias_estudo.minutos_liquidos + EXCLUDED.minutos_liquidos,
    questoes_resolvidas = public.dias_estudo.questoes_resolvidas + EXCLUDED.questoes_resolvidas,
    questoes_acertos = public.dias_estudo.questoes_acertos + EXCLUDED.questoes_acertos,
    aulas_assistidas = public.dias_estudo.aulas_assistidas + EXCLUDED.aulas_assistidas,
    xp_ganho_dia = public.dias_estudo.xp_ganho_dia + EXCLUDED.xp_ganho_dia,
    atualizado_em = NOW()
  RETURNING minutos_liquidos INTO v_minutos_hoje;

  v_meta_ok := (v_minutos_hoje >= (COALESCE(v_meta_diaria, 1.0) * 30)); -- Ao menos metade da meta diária ou atividade registrada

  UPDATE public.dias_estudo
  SET meta_diaria_cumprida = v_meta_ok
  WHERE user_id = p_user_id AND data_estudo = CURRENT_DATE;

  IF v_ultimo_dia IS NULL OR v_ultimo_dia < (CURRENT_DATE - INTERVAL '1 day') THEN
    v_streak_atual := 1;
  ELSIF v_ultimo_dia = (CURRENT_DATE - INTERVAL '1 day') THEN
    v_streak_atual := COALESCE(v_streak_atual, 0) + 1;
  END IF;

  v_maior_streak := GREATEST(COALESCE(v_maior_streak, 0), COALESCE(v_streak_atual, 1));

  UPDATE public.usuarios
  SET
    ultimo_dia_estudo = CURRENT_DATE,
    streak_atual_dias = v_streak_atual,
    maior_streak_dias = v_maior_streak,
    atualizado_em = NOW()
  WHERE id = p_user_id;

  RETURN QUERY SELECT v_streak_atual, v_maior_streak, v_meta_ok;
END;
$$;

-- ============================================================================
-- 10. FUNÇÃO RPC: fn_avaliar_conquistas_aluno
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_avaliar_conquistas_aluno(
  p_user_id TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conquista RECORD;
  v_valor_atual NUMERIC(10,2);
  v_pct NUMERIC(5,2);
  v_desbloqueou BOOLEAN;
  v_novas_desbloqueadas INTEGER := 0;
  v_streak INTEGER;
  v_horas NUMERIC(10,2);
  v_questoes BIGINT;
  v_melhor_simulado NUMERIC(5,2);
  v_is_premium NUMERIC(10,2);
BEGIN
  SELECT
    GREATEST(COALESCE(u.streak_atual_dias, 0), COALESCE(u.maior_streak_dias, 0)),
    CASE WHEN u.tipo_assinatura IN ('premium', 'pro', 'anual') THEN 1 ELSE 0 END
  INTO v_streak, v_is_premium
  FROM public.usuarios u
  WHERE u.id = p_user_id;

  SELECT COALESCE(SUM(horas_liquidas), 0) INTO v_horas
  FROM public.dias_estudo WHERE user_id = p_user_id;

  SELECT COUNT(*) INTO v_questoes
  FROM public.question_attempts WHERE user_id = p_user_id;

  SELECT COALESCE(MAX(percentual_acerto), 0) INTO v_melhor_simulado
  FROM public.simulado_tentativas WHERE user_id = p_user_id AND status = 'concluido';

  FOR v_conquista IN SELECT * FROM public.conquistas WHERE ativa = true ORDER BY ordem LOOP
    v_valor_atual := CASE v_conquista.regra_tipo
      WHEN 'streak_dias' THEN v_streak
      WHEN 'horas_estudo' THEN v_horas
      WHEN 'questoes_resolvidas' THEN v_questoes
      WHEN 'nota_simulado' THEN v_melhor_simulado
      WHEN 'assinatura_ativa' THEN v_is_premium
      ELSE 0
    END;

    v_pct := LEAST(100.00, ROUND((v_valor_atual / GREATEST(1, v_conquista.meta_valor)) * 100.0, 2));
    v_desbloqueou := (v_valor_atual >= v_conquista.meta_valor);

    INSERT INTO public.aluno_conquistas (
      user_id, conquista_id, progresso_atual, progresso_meta, progresso_percentual,
      desbloqueada, desbloqueada_em
    )
    VALUES (
      p_user_id, v_conquista.id, LEAST(v_valor_atual, v_conquista.meta_valor),
      v_conquista.meta_valor, v_pct, v_desbloqueou,
      CASE WHEN v_desbloqueou THEN NOW() ELSE NULL END
    )
    ON CONFLICT (user_id, conquista_id) DO UPDATE SET
      progresso_atual = LEAST(v_valor_atual, v_conquista.meta_valor),
      progresso_percentual = v_pct,
      desbloqueada = (public.aluno_conquistas.desbloqueada OR v_desbloqueou),
      desbloqueada_em = COALESCE(
        public.aluno_conquistas.desbloqueada_em,
        CASE WHEN v_desbloqueou THEN NOW() ELSE NULL END
      ),
      atualizado_em = NOW();

    IF v_desbloqueou THEN
      v_novas_desbloqueadas := v_novas_desbloqueadas + 1;
    END IF;
  END LOOP;

  RETURN v_novas_desbloqueadas;
END;
$$;

-- ============================================================================
-- 11. FUNÇÃO RPC: fn_calcular_revisao_sm2 (Algoritmo SuperMemo SM-2)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_calcular_revisao_sm2(
  p_revisao_id UUID,
  p_qualidade INTEGER -- 0 a 5 (0..2 = esqueceu, 3 = difícil, 4 = bom, 5 = fácil)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rev RECORD;
  v_rep INTEGER;
  v_ef NUMERIC(4,2);
  v_int INTEGER;
  v_prox DATE;
  v_ciclo TEXT;
BEGIN
  SELECT * INTO v_rev FROM public.revisoes_espacadas_sm2 WHERE id = p_revisao_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Revisão SM-2 % não encontrada', p_revisao_id;
  END IF;

  IF p_qualidade < 3 THEN
    v_rep := 0;
    v_int := 1;
  ELSE
    v_rep := v_rev.repeticoes + 1;
    IF v_rep = 1 THEN
      v_int := 1;
    ELSIF v_rep = 2 THEN
      v_int := 7;
    ELSE
      v_int := ROUND(v_rev.intervalo_dias * v_rev.fator_facilidade)::INTEGER;
    END IF;
  END IF;

  v_ef := GREATEST(
    1.30,
    v_rev.fator_facilidade + (0.1 - (5 - p_qualidade) * (0.08 + (5 - p_qualidade) * 0.02))
  );

  v_prox := CURRENT_DATE + v_int;
  v_ciclo := CASE
    WHEN v_int <= 1 THEN '24h'
    WHEN v_int <= 7 THEN '7d'
    WHEN v_int <= 15 THEN '15d'
    ELSE '30d'
  END;

  UPDATE public.revisoes_espacadas_sm2
  SET
    repeticoes = v_rep,
    fator_facilidade = v_ef,
    intervalo_dias = v_int,
    ultima_nota_qualidade = p_qualidade,
    proxima_revisao_em = v_prox,
    ciclo_label = v_ciclo,
    status = 'pendente',
    ultima_revisao_em = NOW(),
    atualizado_em = NOW()
  WHERE id = p_revisao_id;

  RETURN jsonb_build_object(
    'id', p_revisao_id,
    'repeticoes', v_rep,
    'fator_facilidade', v_ef,
    'intervalo_dias', v_int,
    'proxima_revisao_em', v_prox,
    'ciclo_label', v_ciclo
  );
END;
$$;
