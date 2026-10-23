-- Agon: catálogo de questões e gravação atômica de respostas.
-- Operações com gabarito e tentativas são feitas exclusivamente no servidor.

ALTER TABLE public.questoes
  ADD COLUMN IF NOT EXISTS origem TEXT NOT NULL DEFAULT 'manual'
    CHECK (origem IN ('manual', 'importacao_pdf', 'ia')),
  ADD COLUMN IF NOT EXISTS fonte_url TEXT,
  ADD COLUMN IF NOT EXISTS revisada_por TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS revisada_em TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_questoes_filtros ON public.questoes(disciplina_slug, banca_sigla, ano, dificuldade);
CREATE INDEX IF NOT EXISTS idx_question_attempts_user_questao ON public.question_attempts(user_id, questao_uuid, criado_em DESC);

-- O gabarito oficial e a coluna correta das alternativas nunca são acessíveis
-- pelo papel usado pelos clientes. O backend usa a chave secreta de serviço.
ALTER TABLE public.questoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questao_alternativas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS questoes_select_public ON public.questoes;
DROP POLICY IF EXISTS questoes_select_ativas ON public.questoes;
CREATE POLICY questoes_select_ativas ON public.questoes
  FOR SELECT TO authenticated USING (ativa = true AND anulada = false);
DROP POLICY IF EXISTS questao_alternativas_select_public ON public.questao_alternativas;
DROP POLICY IF EXISTS questao_alternativas_select_ativas ON public.questao_alternativas;
CREATE POLICY questao_alternativas_select_ativas ON public.questao_alternativas
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.questoes q
      WHERE q.id = questao_id AND q.ativa = true AND q.anulada = false
    )
  );
REVOKE ALL ON public.questoes FROM anon, authenticated;
GRANT SELECT (id, codigo, disciplina_id, assunto_id, banca_id, concurso_id,
  disciplina_slug, disciplina_nome, assunto_nome, banca_sigla, ano, orgao_cargo,
  modalidade, dificuldade, texto_associado, enunciado, professor_autor,
  professor_cargo, gerada_por_ia, desatualizada, total_respostas,
  total_acertos, ativa, origem, fonte_url, revisada_por, revisada_em,
  criado_em, atualizado_em) ON public.questoes TO authenticated;
REVOKE ALL ON public.questao_alternativas FROM anon, authenticated;
GRANT SELECT (id, questao_id, letra, texto, ordem, criado_em)
  ON public.questao_alternativas TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_registrar_resposta_questao(
  p_user_id TEXT,
  p_questao_id UUID,
  p_resposta TEXT,
  p_tempo_gasto_segundos INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_q public.questoes%ROWTYPE;
  v_resposta TEXT := upper(trim(p_resposta));
  v_acertou BOOLEAN;
  v_xp INTEGER := 0;
  v_total INTEGER;
  v_acertos INTEGER;
  v_erros INTEGER;
  v_tempo INTEGER;
  v_taxa_acerto INTEGER;
  v_taxa_erro INTEGER;
  v_classificacao TEXT;
  v_justificativas JSONB;
BEGIN
  IF p_user_id IS NULL OR length(trim(p_user_id)) = 0 THEN
    RAISE EXCEPTION 'Usuário inválido' USING ERRCODE = '22023';
  END IF;
  IF p_tempo_gasto_segundos IS NULL OR p_tempo_gasto_segundos < 0 OR p_tempo_gasto_segundos > 7200 THEN
    RAISE EXCEPTION 'Tempo inválido' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_q FROM public.questoes
    WHERE id = p_questao_id AND ativa = true AND anulada = false FOR SHARE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('erro', 'QUESTAO_INDISPONIVEL');
  END IF;
  IF (v_q.modalidade = 'certo_errado' AND v_resposta NOT IN ('C', 'E'))
     OR (v_q.modalidade = 'multipla_escolha' AND v_resposta NOT IN ('A', 'B', 'C', 'D', 'E')) THEN
    RETURN jsonb_build_object('erro', 'RESPOSTA_INVALIDA');
  END IF;

  v_acertou := v_resposta = upper(trim(v_q.gabarito_oficial));
  v_xp := CASE
    WHEN v_acertou AND NOT EXISTS (
      SELECT 1 FROM public.question_attempts qa
      WHERE qa.user_id = p_user_id AND qa.questao_uuid = v_q.id AND qa.acertou = true
    ) THEN 10
    ELSE 0
  END;

  INSERT INTO public.question_attempts (
    id, user_id, question_id, disciplina, assunto, subassunto,
    resposta_selecionada, resposta_correta, acertou, tempo_gasto_segundos,
    origem, banca, ano, tentativa_num, criado_em, questao_uuid, xp_ganho,
    modo_resolucao
  ) VALUES (
    'att_' || gen_random_uuid()::text, p_user_id, v_q.codigo,
    v_q.disciplina_nome, v_q.assunto_nome, '', v_resposta,
    upper(trim(v_q.gabarito_oficial)), v_acertou, p_tempo_gasto_segundos,
    CASE WHEN v_q.gerada_por_ia THEN 'ia_gerada' ELSE 'cadastrada' END,
    v_q.banca_sigla, v_q.ano::text,
    (SELECT count(*)::integer + 1 FROM public.question_attempts
      WHERE user_id = p_user_id AND questao_uuid = v_q.id),
    now(), v_q.id, v_xp, 'avulsa'
  );

  UPDATE public.questoes SET
    total_respostas = total_respostas + 1,
    total_acertos = total_acertos + CASE WHEN v_acertou THEN 1 ELSE 0 END
  WHERE id = v_q.id;

  INSERT INTO public.student_topic_stats (
    id, user_id, disciplina, assunto, total_respondidas, total_acertos,
    total_erros, tempo_total_segundos, taxa_acerto, taxa_erro,
    classificacao_dificuldade, ultima_atividade
  ) VALUES (
    p_user_id || '_' || regexp_replace(lower(v_q.disciplina_nome), '[^a-z0-9]+', '_', 'g') || '_' || regexp_replace(lower(v_q.assunto_nome), '[^a-z0-9]+', '_', 'g'),
    p_user_id, v_q.disciplina_nome, v_q.assunto_nome, 1,
    CASE WHEN v_acertou THEN 1 ELSE 0 END, CASE WHEN v_acertou THEN 0 ELSE 1 END,
    p_tempo_gasto_segundos, CASE WHEN v_acertou THEN 100 ELSE 0 END,
    CASE WHEN v_acertou THEN 0 ELSE 100 END, 'dados_insuficientes', now()
  ) ON CONFLICT (id) DO UPDATE SET
    total_respondidas = student_topic_stats.total_respondidas + 1,
    total_acertos = student_topic_stats.total_acertos + CASE WHEN v_acertou THEN 1 ELSE 0 END,
    total_erros = student_topic_stats.total_erros + CASE WHEN v_acertou THEN 0 ELSE 1 END,
    tempo_total_segundos = student_topic_stats.tempo_total_segundos + p_tempo_gasto_segundos,
    taxa_acerto = round(((student_topic_stats.total_acertos + CASE WHEN v_acertou THEN 1 ELSE 0 END)::numeric / (student_topic_stats.total_respondidas + 1)) * 100)::integer,
    taxa_erro = 100 - round(((student_topic_stats.total_acertos + CASE WHEN v_acertou THEN 1 ELSE 0 END)::numeric / (student_topic_stats.total_respondidas + 1)) * 100)::integer,
    classificacao_dificuldade = CASE
      WHEN student_topic_stats.total_respondidas + 1 < 5 THEN 'dados_insuficientes'
      WHEN (100 - round(((student_topic_stats.total_acertos + CASE WHEN v_acertou THEN 1 ELSE 0 END)::numeric / (student_topic_stats.total_respondidas + 1)) * 100)) >= 60 THEN 'alta'
      WHEN (100 - round(((student_topic_stats.total_acertos + CASE WHEN v_acertou THEN 1 ELSE 0 END)::numeric / (student_topic_stats.total_respondidas + 1)) * 100)) >= 35 THEN 'moderada'
      ELSE 'em_desenvolvimento' END,
    ultima_atividade = now();

  IF NOT v_acertou THEN
    INSERT INTO public.caderno_erros (user_id, questao_id, question_codigo, disciplina_nome, assunto_nome, banca_nome)
    VALUES (p_user_id, v_q.id, v_q.codigo, v_q.disciplina_nome, v_q.assunto_nome, v_q.banca_sigla)
    ON CONFLICT (user_id, question_codigo) DO UPDATE SET
      vezes_errada = caderno_erros.vezes_errada + 1,
      dominada = false,
      dominada_em = NULL,
      atualizado_em = now();
  END IF;

  INSERT INTO public.dias_estudo (user_id, data_estudo, questoes_resolvidas, questoes_acertos, xp_ganho_dia)
  VALUES (p_user_id, current_date, 1, CASE WHEN v_acertou THEN 1 ELSE 0 END, v_xp)
  ON CONFLICT (user_id, data_estudo) DO UPDATE SET
    questoes_resolvidas = dias_estudo.questoes_resolvidas + 1,
    questoes_acertos = dias_estudo.questoes_acertos + CASE WHEN v_acertou THEN 1 ELSE 0 END,
    xp_ganho_dia = dias_estudo.xp_ganho_dia + v_xp;

  IF v_xp > 0 THEN
    PERFORM * FROM public.fn_registrar_xp_aluno(p_user_id, v_xp, 'questao_correta', 'Resposta correta em ' || v_q.codigo, v_q.id::text);
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'letra', letra, 'correta', letra = upper(trim(v_q.gabarito_oficial)),
    'justificativa', justificativa_alternativa
  ) ORDER BY ordem), '[]'::jsonb)
  INTO v_justificativas FROM public.questao_alternativas WHERE questao_id = v_q.id;

  RETURN jsonb_build_object(
    'acertou', v_acertou,
    'gabarito', upper(trim(v_q.gabarito_oficial)),
    'comentario_professor', v_q.comentario_professor,
    'justificativas', v_justificativas,
    'xp_ganho', v_xp
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_registrar_resposta_questao(TEXT, UUID, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_registrar_resposta_questao(TEXT, UUID, TEXT, INTEGER) TO service_role;
