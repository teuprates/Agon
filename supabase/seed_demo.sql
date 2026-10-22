-- ============================================================================
-- AGON — Seed Opcional de Demonstração (`supabase/seed_demo.sql`)
-- ============================================================================
-- ⚠️ AVISO IMPORTANTE:
-- Este arquivo contém EXCLUSIVAMENTE dados de demonstração ("Davi Brito" e
-- colegas fictícios da comunidade) para testar os protótipos visuais com dados
-- ricos. NÃO execute este arquivo em produção caso deseje o banco limpo apenas
-- com o catálogo oficial (`supabase/seed.sql`).
-- Requer que `supabase/seed.sql` já tenha sido executado antes.
-- ============================================================================

-- ============================================================================
-- 1. USUÁRIOS DE DEMONSTRAÇÃO (Davi Brito e membros da Comunidade)
-- ============================================================================
INSERT INTO public.usuarios (
  id, nome, email, senha, telefone, tipo_usuario, tipo_assinatura,
  pontos_gamificacao, cidade_uf, bio, avatar_url, concurso_foco_id,
  cargo_desejado, nivel_atual, streak_atual_dias, maior_streak_dias,
  ultimo_dia_estudo, meta_horas_semanal, meta_horas_diaria
)
VALUES
  (
    'demo_user_davi_brito',
    'Davi Brito',
    'davi.brito@exemplo.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', -- hash bcrypt demonstrativo
    '(11) 98765-4321',
    'aluno',
    'premium',
    1800,
    'São Paulo, SP',
    'Focado na aprovação para Agente da Polícia Federal! Estudando 4h por dia com constância e fé.',
    '/assets/img/perfil.jpg',
    '22222222-2222-4222-8222-222222222201',
    'Polícia Federal — Agente',
    12,
    12,
    23,
    CURRENT_DATE,
    15.00,
    3.50
  ),
  (
    'demo_user_mariana_silva',
    'Mariana Silva',
    'mariana.silva@exemplo.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    '(61) 99111-2233',
    'aluno',
    'premium',
    2450,
    'Brasília, DF',
    'Rumo à Polícia Federal 2026!',
    'https://i.pravatar.cc/150?img=32',
    '22222222-2222-4222-8222-222222222201',
    'Polícia Federal — Agente',
    13,
    21,
    28,
    CURRENT_DATE,
    24.00,
    4.00
  ),
  (
    'demo_user_carlos_eduardo',
    'Carlos Eduardo',
    'carlos.eduardo@exemplo.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    '(21) 99222-3344',
    'aluno',
    'premium',
    2100,
    'Rio de Janeiro, RJ',
    'Foco total na Receita Federal e Fiscos Estaduais.',
    'https://i.pravatar.cc/150?img=12',
    '22222222-2222-4222-8222-222222222202',
    'Receita Federal — Auditor-Fiscal',
    12,
    15,
    19,
    CURRENT_DATE,
    20.00,
    3.50
  ),
  (
    'demo_user_fernanda_costa',
    'Fernanda Costa',
    'fernanda.costa@exemplo.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    '(11) 99333-4455',
    'aluno',
    'premium',
    1650,
    'Campinas, SP',
    'Escrevente TJ-SP • Foco Vunesp',
    'https://i.pravatar.cc/150?img=47',
    '22222222-2222-4222-8222-222222222203',
    'TJ-SP — Escrevente Técnico Judiciário',
    11,
    10,
    14,
    CURRENT_DATE,
    18.00,
    3.00
  )
ON CONFLICT (id) DO UPDATE SET
  pontos_gamificacao = EXCLUDED.pontos_gamificacao,
  nivel_atual = EXCLUDED.nivel_atual,
  streak_atual_dias = EXCLUDED.streak_atual_dias;

-- Preferências de Davi Brito (`configuracoes.html`)
INSERT INTO public.usuario_preferencias (
  user_id, tema, tamanho_fonte_questoes, mostrar_cronometro_questoes,
  ocultar_comentarios_automaticamente, notif_lembrete_diario, horario_lembrete_diario,
  notif_novos_simulados_editais, notif_resumo_semanal_email
)
VALUES (
  'demo_user_davi_brito', 'light', 'padrao', true, false, true, '19:00:00', true, false
)
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- 2. CONCURSOS ACOMPANHADOS NO DASHBOARD (`index.html`)
-- ============================================================================
INSERT INTO public.aluno_concursos_acompanhados (
  user_id, concurso_id, foco_principal, status_acompanhamento, topicos_concluidos, total_topicos, progresso_percentual
)
VALUES
  ('demo_user_davi_brito', '22222222-2222-4222-8222-222222222201', true,  'foco_principal', 720, 1000, 72.00),
  ('demo_user_davi_brito', '22222222-2222-4222-8222-222222222202', false, 'em_andamento',   450, 1000, 45.00),
  ('demo_user_davi_brito', '22222222-2222-4222-8222-222222222203', false, 'iniciando',      300, 1000, 30.00)
ON CONFLICT (user_id, concurso_id) DO UPDATE SET
  progresso_percentual = EXCLUDED.progresso_percentual,
  topicos_concluidos = EXCLUDED.topicos_concluidos;

-- ============================================================================
-- 3. HISTÓRICO DE DIAS DE ESTUDO (Últimos 7 dias Seg–Dom em `index.html`)
-- ============================================================================
INSERT INTO public.dias_estudo (
  user_id, data_estudo, minutos_liquidos, questoes_resolvidas, questoes_acertos, aulas_assistidas, xp_ganho_dia, meta_diaria_cumprida
)
VALUES
  ('demo_user_davi_brito', CURRENT_DATE - 6, 240, 40, 31, 1, 180, true),
  ('demo_user_davi_brito', CURRENT_DATE - 5, 330, 55, 44, 2, 240, true),
  ('demo_user_davi_brito', CURRENT_DATE - 4, 180, 30, 22, 1, 130, true),
  ('demo_user_davi_brito', CURRENT_DATE - 3, 360, 60, 48, 2, 260, true),
  ('demo_user_davi_brito', CURRENT_DATE - 2, 270, 45, 35, 1, 190, true),
  ('demo_user_davi_brito', CURRENT_DATE - 1, 420, 75, 60, 3, 350, true),
  ('demo_user_davi_brito', CURRENT_DATE,     300, 50, 41, 2, 250, true)
ON CONFLICT (user_id, data_estudo) DO UPDATE SET
  minutos_liquidos = EXCLUDED.minutos_liquidos,
  questoes_resolvidas = EXCLUDED.questoes_resolvidas;

-- ============================================================================
-- 4. CONQUISTAS DO ALUNO DEMO (`conquistas.html`)
-- ============================================================================
INSERT INTO public.aluno_conquistas (
  user_id, conquista_id, progresso_atual, progresso_meta, progresso_percentual, desbloqueada, desbloqueada_em
)
VALUES
  ('demo_user_davi_brito', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01', 7,   7,   100.00, true,  NOW() - INTERVAL '5 days'),
  ('demo_user_davi_brito', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02', 40,  40,  100.00, true,  NOW() - INTERVAL '3 days'),
  ('demo_user_davi_brito', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa03', 100, 100, 100.00, true,  NOW() - INTERVAL '2 days'),
  ('demo_user_davi_brito', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa04', 85,  90,  94.44,  false, NULL),
  ('demo_user_davi_brito', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa05', 1,   1,   100.00, true,  NOW() - INTERVAL '30 days'),
  ('demo_user_davi_brito', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa06', 12,  30,  40.00,  false, NULL)
ON CONFLICT (user_id, conquista_id) DO UPDATE SET
  progresso_atual = EXCLUDED.progresso_atual,
  progresso_percentual = EXCLUDED.progresso_percentual,
  desbloqueada = EXCLUDED.desbloqueada;

-- ============================================================================
-- 5. TENTATIVAS DE SIMULADOS (`simulados.html`: 1 não iniciado, 1 em andamento, 1 concluído)
-- ============================================================================
INSERT INTO public.simulado_tentativas (
  id, user_id, simulado_id, status, questao_atual_ordem, questoes_respondidas,
  total_questoes, acertos, erros, em_branco, pontos_brutos, pontos_liquidos,
  percentual_acerto, tempo_decorrido_segundos, tempo_limite_segundos,
  posicao_ranking, percentil, desempenho_por_disciplina, xp_ganho, finalizado_em
)
VALUES
  (
    'f1111111-1111-4111-8111-111111111101',
    'demo_user_davi_brito',
    '88888888-8888-4888-8888-888888888801',
    'em_andamento', 55, 54, 120, 42, 12, 66, 42.00, 30.00, 45.00,
    5400, 16200, NULL, NULL, '[]'::jsonb, 0, NULL
  ),
  (
    'f1111111-1111-4111-8111-111111111102',
    'demo_user_davi_brito',
    '88888888-8888-4888-8888-888888888802',
    'concluido', 80, 80, 80, 68, 12, 0, 68.00, 68.00, 85.00,
    9900, 10800, 14, 95.00,
    '[{"disciplina": "Direito Tributário", "acertos": 18, "total": 20, "percentual": 90}, {"disciplina": "Legislação Aduaneira", "acertos": 17, "total": 20, "percentual": 85}, {"disciplina": "Contabilidade Geral", "acertos": 18, "total": 20, "percentual": 90}, {"disciplina": "Língua Portuguesa", "acertos": 15, "total": 20, "percentual": 75}]'::jsonb,
    400, NOW() - INTERVAL '2 days'
  )
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  questoes_respondidas = EXCLUDED.questoes_respondidas,
  percentual_acerto = EXCLUDED.percentual_acerto;

-- ============================================================================
-- 6. NOTIFICAÇÕES E ATIVIDADES RECENTES (`index.html`)
-- ============================================================================
INSERT INTO public.notificacoes (id, user_id, tipo, titulo, mensagem, icone, cor_tema, link_destino, lida)
VALUES
  ('f2222222-2222-4222-8222-222222222201', 'demo_user_davi_brito', 'simulado', 'Novo Simulado Disponível', 'Novo simulado da Polícia Federal disponível!', 'fa-bell', 'blue', '/simulados', false),
  ('f2222222-2222-4222-8222-222222222202', 'demo_user_davi_brito', 'conquista', 'Badge Conquistado!', 'Você conquistou o badge Foco Total! 🎉', 'fa-trophy', 'green', '/conquistas', false),
  ('f2222222-2222-4222-8222-222222222203', 'demo_user_davi_brito', 'meta_diaria', 'Meta Diária Quase Lá', 'Sua meta diária está 80% completa.', 'fa-clock', 'orange', '/planos-estudo', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.atividades_recentes (id, user_id, tipo, titulo, subtitulo, xp_ganho, icone, cor_badge)
VALUES
  ('f3333333-3333-4333-8333-333333333301', 'demo_user_davi_brito', 'questoes', '20 questões Dir.Adm', 'Direito Administrativo • 85% acertos', 200, 'fa-list-check', 'green'),
  ('f3333333-3333-4333-8333-333333333302', 'demo_user_davi_brito', 'aula', 'Princípios Adm. Pública', 'Vídeo-aula assistida • 48 min', 150, 'fa-circle-play', 'blue'),
  ('f3333333-3333-4333-8333-333333333303', 'demo_user_davi_brito', 'simulado', 'Simulado PF Rodada 3', '60 itens respondidos • 76% acerto', 350, 'fa-file-signature', 'purple')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 7. ASSINATURA & FATURAS DE DEMONSTRAÇÃO (`configuracoes.html`)
-- ============================================================================
INSERT INTO public.assinaturas (
  id, user_id, plano_id, status, valor_contratado, metodo_pagamento,
  cartao_bandeira, cartao_ultimos4, cartao_validade, proxima_cobranca_em
)
VALUES (
  'f4444444-4444-4444-8444-444444444401',
  'demo_user_davi_brito',
  'cccccccc-cccc-4ccc-8ccc-cccccccccc03',
  'ativa', 39.90, 'cartao_credito', 'Mastercard', '8492', '09/2029', '2026-10-15'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.faturas (id, assinatura_id, user_id, codigo_fatura, descricao, competencia_data, valor, status)
VALUES
  ('f5555555-5555-4555-8555-555555555501', 'f4444444-4444-4444-8444-444444444401', 'demo_user_davi_brito', 'INV-2025-1015', 'Plano Agon Pro Anual (Renovação)', '2025-10-15', 478.80, 'pago'),
  ('f5555555-5555-4555-8555-555555555502', 'f4444444-4444-4444-8444-444444444401', 'demo_user_davi_brito', 'INV-2025-0915', 'Simulado Extra Comentado PF', '2025-09-15', 39.90, 'pago'),
  ('f5555555-5555-4555-8555-555555555503', 'f4444444-4444-4444-8444-444444444401', 'demo_user_davi_brito', 'INV-2025-0815', 'Assinatura Mensal Agon Pro', '2025-08-15', 39.90, 'pago')
ON CONFLICT (codigo_fatura) DO NOTHING;

-- ============================================================================
-- 8. PUBLICAÇÕES E ENQUETES DA COMUNIDADE (`comunidade.html`)
-- ============================================================================
INSERT INTO public.comunidade_posts (
  id, user_id, autor_nome, autor_avatar_url, autor_cargo_meta, autor_badge,
  autor_cor_badge, autor_subtitulo, categoria, titulo, conteudo,
  possui_enquete, fixado, total_curtidas, total_comentarios
)
VALUES
  (
    'f6666666-6666-4666-8666-666666666601',
    'demo_user_mariana_silva', 'Mariana Silva', 'https://i.pravatar.cc/150?img=32',
    'Meta: Agente PF • Nível 14', 'Polícia Federal', 'blue', 'Há 2 horas • Meta: Agente PF • Nível 14',
    'duvidas',
    'Alguém tem um bizu definitivo para não confundir nunca mais Habeas Data com Mandado de Segurança na banca Cebraspe?',
    'Pessoal, estava resolvendo um caderno de questões da PF 2021 e caí em uma pegadinha clássica sobre negativa de certidão para defesa de direitos versus acesso a informações pessoais constantes de banco de dados governamental. Como vocês costumam separar isso rápido na hora da prova?',
    false, true, 42, 2
  ),
  (
    'f6666666-6666-4666-8666-666666666602',
    'demo_user_carlos_eduardo', 'Carlos Eduardo', 'https://i.pravatar.cc/150?img=12',
    'Meta: Auditor RFB • Nível 12', 'Língua Portuguesa', 'purple', 'Há 5 horas • Meta: Auditor RFB • Nível 12',
    'resumos',
    'Mapa Rápido: Os 5 casos em que a Crase é PROIBIDA na FGV e Cebraspe 🚀',
    'Salvem esse resumo rápido para revisar 5 minutos antes do simulado! Esses 5 casos respondem praticamente 80% das questões de crase em provas fiscais e policiais.',
    false, false, 89, 14
  ),
  (
    'f6666666-6666-4666-8666-666666666603',
    'demo_user_fernanda_costa', 'Fernanda Costa', 'https://i.pravatar.cc/150?img=47',
    'Meta: Escrevente TJ-SP • Nível 11', 'Editais & Carreiras', 'orange', 'Ontem às 18:40 • Meta: Escrevente TJ-SP • Nível 11',
    'editais',
    'Enquete rápida da semana: Qual matéria está consumindo mais tempo do seu ciclo atual de estudos?',
    'Estou ajustando meu cronograma semanal aqui no Agon para o pós-edital e queria saber onde a galera está concentrando mais energia nesta reta final!',
    true, false, 31, 9
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.comunidade_post_hashtags (post_id, hashtag, descricao_topico)
VALUES
  ('f6666666-6666-4666-8666-666666666601', '#PolíciaFederal2026', 'Discussões sobre o próximo edital'),
  ('f6666666-6666-4666-8666-666666666601', '#DireitoConstitucional', 'Remédios Constitucionais e Art. 5º'),
  ('f6666666-6666-4666-8666-666666666602', '#DicasDePortuguês', 'Mnemônicos e sintaxe FGV'),
  ('f6666666-6666-4666-8666-666666666603', '#DireitoAdministrativo', 'Nova Lei de Licitações (14.133)')
ON CONFLICT (post_id, hashtag) DO NOTHING;

INSERT INTO public.comunidade_enquete_opcoes (id, post_id, texto_opcao, votos_count, ordem)
VALUES
  ('f7777777-7777-4777-8777-777777777701', 'f6666666-6666-4666-8666-666666666603', 'Informática / Tecnologia da Informação (PF)', 66, 1),
  ('f7777777-7777-4777-8777-777777777702', 'f6666666-6666-4666-8666-666666666603', 'Contabilidade Geral & Direito Tributário', 44, 2),
  ('f7777777-7777-4777-8777-777777777703', 'f6666666-6666-4666-8666-666666666603', 'Português & Redação Discursiva', 27, 3),
  ('f7777777-7777-4777-8777-777777777704', 'f6666666-6666-4666-8666-666666666603', 'Direito Constitucional & Administrativo', 19, 4)
ON CONFLICT (id) DO NOTHING;
