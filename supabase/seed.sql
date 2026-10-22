-- ============================================================================
-- AGON — Seed Oficial de Catálogo (`supabase/seed.sql`)
-- ============================================================================
-- Descrição: Popula o banco de dados com o catálogo pedagógico real extraído
-- das páginas HTML do AGON (Bancas, Concursos, Disciplinas, Assuntos, Edital
-- Verticalizado, Questões com Alternativas e Gabarito Comentado, Cursos,
-- Módulos, Videoaulas, Anexos, 8 Materiais PDF, 3 Simulados Oficiais,
-- Tabela de Níveis 1..20, Temporada ativa, 6 Conquistas/Badges, Salas de Estudo
-- Pomodoro, Planos de Assinatura, Fases do Roadmap e Depoimentos da Home).
--
-- IMPORTANTE: Este arquivo contém EXCLUSIVAMENTE dados de catálogo da plataforma.
-- Dados fictícios de alunos ("Davi Brito", faturas, posts de demonstração)
-- estão isolados em `supabase/seed_demo.sql`.
-- Totalmente idempotente (`ON CONFLICT ... DO UPDATE`).
-- ============================================================================

-- ============================================================================
-- 1. BANCAS EXAMINADORAS (4)
-- ============================================================================
INSERT INTO public.bancas (id, slug, nome, sigla, descricao, estilo_padrao, fator_penalidade_padrao)
VALUES
  ('11111111-1111-4111-8111-111111111101', 'cebraspe', 'Centro Brasileiro de Pesquisa em Avaliação e Seleção e de Promoção de Eventos', 'Cebraspe', 'Banca tradicional de concursos policiais e federais, célebre pelo método Certo/Errado (1 errada anula 1 certa).', 'certo_errado', 1.00),
  ('11111111-1111-4111-8111-111111111102', 'fgv', 'Fundação Getulio Vargas', 'FGV', 'Banca de alta complexidade interpretativa, referência na Receita Federal, OAB, Tribunais e Fiscos Estaduais.', 'multipla_escolha', 0.00),
  ('11111111-1111-4111-8111-111111111103', 'vunesp', 'Fundação para o Vestibular da Universidade Estadual Paulista', 'Vunesp', 'Banca oficial do TJ-SP, PC-SP e concursos estaduais paulistas, com forte cobrança de literalidade legal.', 'multipla_escolha', 0.00),
  ('11111111-1111-4111-8111-111111111104', 'fcc', 'Fundação Carlos Chagas', 'FCC', 'Banca clássica de Tribunais Regionais Federais (TRFs), TRTs e áreas fiscais.', 'multipla_escolha', 0.00)
ON CONFLICT (slug) DO UPDATE SET
  nome = EXCLUDED.nome,
  sigla = EXCLUDED.sigla,
  descricao = EXCLUDED.descricao,
  estilo_padrao = EXCLUDED.estilo_padrao,
  fator_penalidade_padrao = EXCLUDED.fator_penalidade_padrao;

-- ============================================================================
-- 2. CONCURSOS PÚBLICOS (4 Carreiras Principais)
-- ============================================================================
INSERT INTO public.concursos (
  id, slug, sigla, nome, orgao, cargo, carreira, banca_id, ano, status_edital,
  data_prova, vagas, remuneracao_inicial, total_topicos_edital, ciclo_sugerido_dias,
  descricao_curta, icone, cor_tema, destaque_home
)
VALUES
  (
    '22222222-2222-4222-8222-222222222201',
    'pf-agente', 'PF', 'Polícia Federal — Agente & Escrivão', 'Departamento de Polícia Federal',
    'Agente de Polícia Federal', 'policial', '11111111-1111-4111-8111-111111111101',
    2026, 'autorizado', '2026-11-15', 1000, 13900.54, 1000, 120,
    'Ciclo de 120 dias com Simulados Cebraspe • Foco em TI, Contabilidade, Penal e Constitucional',
    'fa-shield-halved', 'blue', true
  ),
  (
    '22222222-2222-4222-8222-222222222202',
    'rfb-auditor', 'RFB', 'Receita Federal — Auditor-Fiscal', 'Secretaria Especial da Receita Federal do Brasil',
    'Auditor-Fiscal da Receita Federal', 'fiscal', '11111111-1111-4111-8111-111111111102',
    2026, 'previsto', '2026-12-06', 699, 21029.09, 1000, 180,
    'Contabilidade, Direito Tributário, Legislação Aduaneira & TI de Alta Densidade',
    'fa-building-columns', 'green', true
  ),
  (
    '22222222-2222-4222-8222-222222222203',
    'tjsp-escrevente', 'TJ-SP', 'TJ-SP & Tribunais Federais', 'Tribunal de Justiça do Estado de São Paulo',
    'Escrevente Técnico Judiciário', 'tribunais', '11111111-1111-4111-8111-111111111103',
    2026, 'edital_publicado', '2026-10-25', 572, 6043.54, 1000, 90,
    'Foco em Legislação Vunesp/FCC • Mais de 8.000 questões com gabarito comentado',
    'fa-scale-balanced', 'purple', true
  ),
  (
    '22222222-2222-4222-8222-222222222204',
    'inss-tecnico', 'INSS', 'INSS — Técnico do Seguro Social', 'Instituto Nacional do Seguro Social',
    'Técnico do Seguro Social', 'previdenciaria', '11111111-1111-4111-8111-111111111101',
    2026, 'previsto', '2026-11-29', 1000, 5905.79, 800, 90,
    'Seguridade Social, Direito Administrativo, Constitucional e Ética no Serviço Público',
    'fa-id-card', 'cyan', false
  )
ON CONFLICT (slug) DO UPDATE SET
  nome = EXCLUDED.nome,
  cargo = EXCLUDED.cargo,
  status_edital = EXCLUDED.status_edital,
  descricao_curta = EXCLUDED.descricao_curta,
  destaque_home = EXCLUDED.destaque_home;

-- ============================================================================
-- 3. DISCIPLINAS (8 Disciplinas do Ecossistema AGON)
-- ============================================================================
INSERT INTO public.disciplinas (id, slug, nome, nome_curto, area, descricao, icone, cor_hex, cor_badge, ordem)
VALUES
  ('33333333-3333-4333-8333-333333333301', 'constitucional', 'Direito Constitucional', 'Dir. Constitucional', 'juridica', 'Teoria da Constituição, Direitos e Garantias Fundamentais (Art. 5º ao 17), Organização do Estado e dos Poderes.', 'fa-scale-balanced', '#23366e', 'blue', 1),
  ('33333333-3333-4333-8333-333333333302', 'administrativo', 'Direito Administrativo', 'Dir. Administrativo', 'juridica', 'Princípios, Poderes, Atos Administrativos, Licitações (Lei 14.133/2021), Agentes Públicos (Lei 8.112/90) e Controle.', 'fa-landmark', '#10B981', 'green', 2),
  ('33333333-3333-4333-8333-333333333303', 'portugues', 'Língua Portuguesa', 'Português', 'basica', 'Compreensão e Interpretação de Textos, Sintaxe, Crase, Concordância, Regência, Pontuação e Redação Oficial.', 'fa-pen-nib', '#8B5CF6', 'purple', 3),
  ('33333333-3333-4333-8333-333333333304', 'raciocinio', 'Raciocínio Lógico', 'Rac. Lógico', 'exatas', 'Lógica Proposicional, Tabelas-Verdade, Equivalências e Negações (Leis de De Morgan), Análise Combinatória e Probabilidade.', 'fa-brain', '#F59E0B', 'orange', 4),
  ('33333333-3333-4333-8333-333333333305', 'informatica', 'Informática & TI', 'Informática', 'tecnologia', 'Redes de Computadores, Protocolos TCP/IP, Segurança da Informação, Banco de Dados, Python e Computação em Nuvem.', 'fa-laptop-code', '#06B6D4', 'cyan', 5),
  ('33333333-3333-4333-8333-333333333306', 'penal', 'Direito Penal & Processual Penal', 'Dir. Penal', 'juridica', 'Teoria do Crime, Tipicidade, Ilicitude, Culpabilidade, Inquérito Policial, Prisões e Provas no CPP.', 'fa-gavel', '#EF4444', 'red', 6),
  ('33333333-3333-4333-8333-333333333307', 'contabilidade', 'Contabilidade Geral', 'Contabilidade', 'contabil_fiscal', 'Patrimônio, Escrituração, Balanço Patrimonial, DRE e Pronunciamentos Contábeis do CPC.', 'fa-calculator', '#3B82F6', 'blue', 7),
  ('33333333-3333-4333-8333-333333333308', 'tributario', 'Direito Tributário & Aduaneiro', 'Dir. Tributário', 'contabil_fiscal', 'Sistema Tributário Nacional, CTN, Crédito Tributário, Impostos Federais e Regulamento Aduaneiro.', 'fa-coins', '#10B981', 'green', 8)
ON CONFLICT (slug) DO UPDATE SET
  nome = EXCLUDED.nome,
  nome_curto = EXCLUDED.nome_curto,
  descricao = EXCLUDED.descricao,
  icone = EXCLUDED.icone,
  cor_badge = EXCLUDED.cor_badge,
  ordem = EXCLUDED.ordem;

-- ============================================================================
-- 4. ASSUNTOS POR DISCIPLINA
-- ============================================================================
INSERT INTO public.assuntos (id, disciplina_id, slug, nome, incidencia_media, ordem)
VALUES
  -- Direito Constitucional
  ('44444444-4444-4444-8444-444444444401', '33333333-3333-4333-8333-333333333301', 'principios-fundamentais', 'Princípios Fundamentais', 'muito_alta', 1),
  ('44444444-4444-4444-8444-444444444402', '33333333-3333-4333-8333-333333333301', 'direitos-garantias-art5', 'Direitos e Garantias Individuais (Art. 5º)', 'muito_alta', 2),
  ('44444444-4444-4444-8444-444444444403', '33333333-3333-4333-8333-333333333301', 'remedios-constitucionais', 'Remédios Constitucionais (HC, HD, MS, MI e AP)', 'muito_alta', 3),
  ('44444444-4444-4444-8444-444444444404', '33333333-3333-4333-8333-333333333301', 'controle-constitucionalidade', 'Controle de Constitucionalidade', 'alta', 4),
  -- Direito Administrativo
  ('44444444-4444-4444-8444-444444444405', '33333333-3333-4333-8333-333333333302', 'atos-administrativos', 'Atos Administrativos', 'muito_alta', 1),
  ('44444444-4444-4444-8444-444444444406', '33333333-3333-4333-8333-333333333302', 'poderes-administrativos', 'Poderes da Administração', 'alta', 2),
  ('44444444-4444-4444-8444-444444444407', '33333333-3333-4333-8333-333333333302', 'licitacoes-contratos-14133', 'Licitações e Contratos (Lei 14.133/2021)', 'muito_alta', 3),
  ('44444444-4444-4444-8444-444444444408', '33333333-3333-4333-8333-333333333302', 'agentes-publicos-8112', 'Agentes Públicos e Lei 8.112/1990', 'alta', 4),
  -- Língua Portuguesa
  ('44444444-4444-4444-8444-444444444409', '33333333-3333-4333-8333-333333333303', 'emprego-da-crase', 'Emprego da Crase', 'muito_alta', 1),
  ('44444444-4444-4444-8444-444444444410', '33333333-3333-4333-8333-333333333303', 'concordancia-regencia', 'Sintaxe, Concordância e Regência Verbal', 'muito_alta', 2),
  -- Raciocínio Lógico
  ('44444444-4444-4444-8444-444444444411', '33333333-3333-4333-8333-333333333304', 'equivalencias-negacao-logica', 'Equivalências e Negação Lógica', 'muito_alta', 1),
  -- Informática
  ('44444444-4444-4444-8444-444444444412', '33333333-3333-4333-8333-333333333305', 'redes-seguranca-tcpip', 'Redes, Protocolos TCP/IP e Segurança da Informação', 'muito_alta', 1),
  -- Direito Penal
  ('44444444-4444-4444-8444-444444444413', '33333333-3333-4333-8333-333333333306', 'teoria-do-crime', 'Teoria do Crime e Inquérito Policial', 'muito_alta', 1)
ON CONFLICT (disciplina_id, slug) DO UPDATE SET
  nome = EXCLUDED.nome,
  incidencia_media = EXCLUDED.incidencia_media,
  ordem = EXCLUDED.ordem;

-- ============================================================================
-- 5. PESOS POR CONCURSO E DISCIPLINA
-- ============================================================================
INSERT INTO public.concurso_disciplina_pesos (concurso_id, disciplina_id, bloco, peso, qtd_questoes_previstas, prioridade)
VALUES
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333305', 'Bloco I', 2.00, 36, 'alta'),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333303', 'Bloco I', 1.50, 24, 'alta'),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333307', 'Bloco II', 1.50, 24, 'alta'),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333301', 'Bloco III', 1.00, 10, 'media'),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333302', 'Bloco III', 1.00, 10, 'media'),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333306', 'Bloco III', 1.25, 16, 'alta')
ON CONFLICT (concurso_id, disciplina_id) DO UPDATE SET
  peso = EXCLUDED.peso,
  qtd_questoes_previstas = EXCLUDED.qtd_questoes_previstas,
  prioridade = EXCLUDED.prioridade;

-- ============================================================================
-- 6. EDITAL VERTICALIZADO (Tópicos Oficiais — `planos-estudo.html`)
-- ============================================================================
INSERT INTO public.edital_topicos (concurso_id, disciplina_id, assunto_id, codigo_item, titulo, prioridade, meta_questoes, ordem)
VALUES
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333301', '44444444-4444-4444-8444-444444444401', '1.1', 'Princípios Fundamentais da República Federativa do Brasil (Arts. 1º a 4º)', 'alta', 50, 1),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333301', '44444444-4444-4444-8444-444444444402', '2.1', 'Direitos e Deveres Individuais e Coletivos (Art. 5º da CF/1988)', 'alta', 80, 2),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333301', '44444444-4444-4444-8444-444444444403', '2.2', 'Remédios Constitucionais: Habeas Corpus, Habeas Data, Mandado de Segurança, Mandado de Injunção e Ação Popular', 'alta', 60, 3),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333302', '44444444-4444-4444-8444-444444444405', '3.1', 'Atos Administrativos: Conceito, Requisitos, Atributos, Classificação e Extinção', 'alta', 70, 4),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333302', '44444444-4444-4444-8444-444444444407', '3.2', 'Nova Lei de Licitações e Contratos Administrativos (Lei nº 14.133/2021)', 'alta', 60, 5),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333303', '44444444-4444-4444-8444-444444444409', '4.1', 'Domínio da Ortografia Oficial, Emprego do Sinal Indicativo de Crase e Regência', 'media', 50, 6),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333305', '44444444-4444-4444-8444-444444444412', '5.1', 'Redes de Computadores, Modelo OSI, Arquitetura TCP/IP e Segurança da Informação', 'alta', 90, 7),
  ('22222222-2222-4222-8222-222222222201', '33333333-3333-4333-8333-333333333304', '44444444-4444-4444-8444-444444444411', '6.1', 'Estruturas Lógicas, Leis de De Morgan, Equivalências e Diagramas Lógicos', 'baixa', 45, 8)
ON CONFLICT (concurso_id, disciplina_id, codigo_item) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  prioridade = EXCLUDED.prioridade,
  meta_questoes = EXCLUDED.meta_questoes;

-- ============================================================================
-- 7. QUESTÕES REAIS DE `questoes.html` (Q#24891, Q#19302, Q#08477) + ALTERNATIVAS
-- ============================================================================
INSERT INTO public.questoes (
  id, codigo, disciplina_id, assunto_id, banca_id, concurso_id,
  disciplina_slug, disciplina_nome, assunto_nome, banca_sigla, ano, orgao_cargo,
  modalidade, dificuldade, enunciado, gabarito_oficial, comentario_professor,
  professor_autor, professor_cargo
)
VALUES
  (
    '55555555-5555-4555-8555-555555555501',
    'Q#24891',
    '33333333-3333-4333-8333-333333333301',
    '44444444-4444-4444-8444-444444444401',
    '11111111-1111-4111-8111-111111111101',
    '22222222-2222-4222-8222-222222222201',
    'constitucional', 'Direito Constitucional', 'Princípios Fundamentais', 'Cebraspe', 2024,
    'PF — Agente de Polícia Federal', 'multipla_escolha', 'media',
    'Acerca dos Princípios Fundamentais previstos no Título I da Constituição Federal de 1988, assinale a alternativa que apresenta corretamente um fundamento da República Federativa do Brasil, distinguindo-o dos objetivos fundamentais e dos princípios que regem as relações internacionais:',
    'B',
    'De acordo com o art. 1º da CF/88 (mnemônico SO-CI-DI-VA-PLU), são fundamentos da República Federativa do Brasil: I - a soberania; II - a cidadania; III - a dignidade da pessoa humana; IV - os valores sociais do trabalho e da livre iniciativa; e V - o pluralismo político. As alternativas A e D trazem objetivos fundamentais (art. 3º), enquanto C e E trazem princípios das relações internacionais (art. 4º).',
    'Prof. Matheus Santos', 'Especialista em Direito Constitucional'
  ),
  (
    '55555555-5555-4555-8555-555555555502',
    'Q#19302',
    '33333333-3333-4333-8333-333333333303',
    '44444444-4444-4444-8444-444444444409',
    '11111111-1111-4111-8111-111111111102',
    '22222222-2222-4222-8222-222222222202',
    'portugues', 'Língua Portuguesa', 'Emprego da Crase', 'FGV', 2023,
    'Receita Federal — Auditor-Fiscal', 'multipla_escolha', 'facil',
    'Assinale a alternativa em que o emprego do acento grave indicativo de crase está em plena conformidade com a norma-padrão da língua portuguesa:',
    'B',
    'Na alternativa B, a locução adverbial feminina "às pressas" exige acento grave obrigatório, assim como ocorre antes de horas determinadas ("às 14h"). Nas demais: (A) não há crase antes de verbo ("a partir"); (C) não há crase antes de pronome indefinido ("a qualquer"); (D) não há crase na expressão "dia a dia" entre palavras repetidas; (E) com artigo indefinido "uma", não ocorre fusão de duas vogais idênticas.',
    'Profa. Camila Duarte', 'Mestre em Letras e Gramática Aplicada'
  ),
  (
    '55555555-5555-4555-8555-555555555503',
    'Q#08477',
    '33333333-3333-4333-8333-333333333304',
    '44444444-4444-4444-8444-444444444411',
    '11111111-1111-4111-8111-111111111103',
    '22222222-2222-4222-8222-222222222203',
    'raciocinio', 'Raciocínio Lógico', 'Equivalências e Negação Lógica', 'Vunesp', 2022,
    'TJSP — Escrevente Técnico Judiciário', 'multipla_escolha', 'dificil',
    'Considere a seguinte afirmação condicional verdadeira: "Se o servidor protocolou o recurso dentro do prazo, então o processo foi analisado pela comissão." Do ponto de vista da lógica proposicional, uma afirmação logicamente equivalente a essa é:',
    'B',
    'Pela regra da Equivalência Contrapositiva de uma condicional (P → Q ≡ ~Q → ~P), inverte-se a ordem das proposições negando ambas ("Inverte e Nega Tudo"): "Se o processo NÃO foi analisado pela comissão, então o servidor NÃO protocolou o recurso dentro do prazo." (Alternativa B). A alternativa C representa a negação (Regra do MANÉ: P ∧ ~Q) e não a equivalência.',
    'Prof. Fernando Costa', 'Especialista em Raciocínio Lógico e Matemática'
  )
ON CONFLICT (codigo) DO UPDATE SET
  enunciado = EXCLUDED.enunciado,
  gabarito_oficial = EXCLUDED.gabarito_oficial,
  comentario_professor = EXCLUDED.comentario_professor;

-- Alternativas de Q#24891
INSERT INTO public.questao_alternativas (questao_id, letra, texto, correta, ordem)
VALUES
  ('55555555-5555-4555-8555-555555555501', 'A', 'Erradicar a pobreza e a marginalização e reduzir as desigualdades sociais e regionais.', false, 1),
  ('55555555-5555-4555-8555-555555555501', 'B', 'Os valores sociais do trabalho e da livre iniciativa, bem como o pluralismo político.', true, 2),
  ('55555555-5555-4555-8555-555555555501', 'C', 'A autodeterminação dos povos, a não-intervenção e a defesa da paz.', false, 3),
  ('55555555-5555-4555-8555-555555555501', 'D', 'Construir uma sociedade livre, justa e solidária, garantindo o desenvolvimento nacional.', false, 4),
  ('55555555-5555-4555-8555-555555555501', 'E', 'A concessão de asilo político e o repúdio ao terrorismo e ao racismo.', false, 5)
ON CONFLICT (questao_id, letra) DO UPDATE SET
  texto = EXCLUDED.texto,
  correta = EXCLUDED.correta;

-- Alternativas de Q#19302
INSERT INTO public.questao_alternativas (questao_id, letra, texto, correta, ordem)
VALUES
  ('55555555-5555-4555-8555-555555555502', 'A', 'O relatório fiscal foi encaminhado à partir das determinações da superintendência.', false, 1),
  ('55555555-5555-4555-8555-555555555502', 'B', 'Os candidatos compareceram às pressas à seção eleitoral antes do fechamento dos portões às 14h.', true, 2),
  ('55555555-5555-4555-8555-555555555502', 'C', 'O auditor dirigiu-se à qualquer repartição disponível para protocolar o auto de infração.', false, 3),
  ('55555555-5555-4555-8555-555555555502', 'D', 'A jurisprudência passou a ser aplicada dia à dia pelos tribunais superiores.', false, 4),
  ('55555555-5555-4555-8555-555555555502', 'E', 'Entregamos os documentos necessários à uma servidora do setor de atendimento.', false, 5)
ON CONFLICT (questao_id, letra) DO UPDATE SET
  texto = EXCLUDED.texto,
  correta = EXCLUDED.correta;

-- Alternativas de Q#08477
INSERT INTO public.questao_alternativas (questao_id, letra, texto, correta, ordem)
VALUES
  ('55555555-5555-4555-8555-555555555503', 'A', 'Se o servidor não protocolou o recurso dentro do prazo, então o processo não foi analisado pela comissão.', false, 1),
  ('55555555-5555-4555-8555-555555555503', 'B', 'Se o processo não foi analisado pela comissão, então o servidor não protocolou o recurso dentro do prazo.', true, 2),
  ('55555555-5555-4555-8555-555555555503', 'C', 'O servidor protocolou o recurso dentro do prazo e o processo não foi analisado pela comissão.', false, 3),
  ('55555555-5555-4555-8555-555555555503', 'D', 'O servidor protocolou o recurso dentro do prazo ou o processo foi analisado pela comissão.', false, 4),
  ('55555555-5555-4555-8555-555555555503', 'E', 'Se o processo foi analisado pela comissão, então o servidor protocolou o recurso dentro do prazo.', false, 5)
ON CONFLICT (questao_id, letra) DO UPDATE SET
  texto = EXCLUDED.texto,
  correta = EXCLUDED.correta;

-- ============================================================================
-- 8. CURSOS, MÓDULOS, VIDEOAULAS E ANEXOS (`aulas.html` e `estudos.html`)
-- ============================================================================
INSERT INTO public.cursos (
  id, slug, titulo, subtitulo, descricao, disciplina_id, concurso_id,
  professor_nome, professor_cargo, carga_horaria_minutos, total_aulas, nivel
)
VALUES
  (
    '66666666-6666-4666-8666-666666666601',
    'direito-constitucional-alta-performance',
    'Direito Constitucional',
    'Trilha de Alta Performance',
    'Curso completo de Direito Constitucional focado em Cebraspe, FGV e Vunesp, cobrindo Teoria da Constituição, Art. 5º, Remédios Constitucionais e Organização do Estado.',
    '33333333-3333-4333-8333-333333333301',
    '22222222-2222-4222-8222-222222222201',
    'Prof. Roberto Vasconcelos',
    'Mestre em Direito Público • Especialista em Concursos Policiais e Fiscais',
    580, 18, 'alta_performance'
  ),
  (
    '66666666-6666-4666-8666-666666666602',
    'direito-administrativo-essencial',
    'Direito Administrativo Esquematizado',
    'Do Zero ao Avançado',
    'Domine Princípios, Poderes, Atos Administrativos, Lei 14.133/2021 e Lei 8.112/1990 com foco nas bancas de maior incidência.',
    '33333333-3333-4333-8333-333333333302',
    '22222222-2222-4222-8222-222222222201',
    'Profª. Camila Duarte',
    'Especialista em Direito Público e Gestão Governamental',
    720, 22, 'alta_performance'
  )
ON CONFLICT (slug) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  subtitulo = EXCLUDED.subtitulo,
  professor_nome = EXCLUDED.professor_nome,
  carga_horaria_minutos = EXCLUDED.carga_horaria_minutos,
  total_aulas = EXCLUDED.total_aulas;

-- Módulos do Curso de Direito Constitucional (`aulas.html`)
INSERT INTO public.modulos (id, curso_id, numero, titulo, bloqueado_por_padrao, ordem)
VALUES
  ('66666666-6666-4666-8666-666666666701', '66666666-6666-4666-8666-666666666601', 1, 'Módulo 1: Teoria Geral da Constituição', false, 1),
  ('66666666-6666-4666-8666-666666666702', '66666666-6666-4666-8666-666666666601', 2, 'Módulo 2: Direitos e Garantias Fundamentais', false, 2),
  ('66666666-6666-4666-8666-666666666703', '66666666-6666-4666-8666-666666666601', 3, 'Módulo 3: Direitos Sociais e Nacionalidade', true, 3)
ON CONFLICT (curso_id, numero) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  bloqueado_por_padrao = EXCLUDED.bloqueado_por_padrao;

-- Aulas do Módulo 2 (`aulas.html`)
INSERT INTO public.aulas (
  id, curso_id, modulo_id, assunto_id, codigo_aula, numero, titulo,
  resumo_teorico, duracao_minutos, duracao_segundos, xp_recompensa, gratuita, ordem
)
VALUES
  (
    '66666666-6666-4666-8666-666666666801',
    '66666666-6666-4666-8666-666666666601', '66666666-6666-4666-8666-666666666702',
    '44444444-4444-4444-8444-444444444402', 'Aula 01', 1,
    'Aula 01: Introdução ao Artigo 5º da CF',
    'Características dos direitos fundamentais: historicidade, universalidade, relatividade (não existem direitos fundamentais absolutos), irrenunciabilidade e eficácia horizontal.',
    35, 2100, 150, true, 1
  ),
  (
    '66666666-6666-4666-8666-666666666802',
    '66666666-6666-4666-8666-666666666601', '66666666-6666-4666-8666-666666666702',
    '44444444-4444-4444-8444-444444444402', 'Aula 02', 2,
    'Aula 02: Direito à Vida e Igualdade Material',
    'Análise da dupla dimensão do direito à vida, vedação à pena de morte (salvo guerra declarada) e isonomia formal vs. material na jurisprudência do STF.',
    40, 2400, 150, false, 2
  ),
  (
    '66666666-6666-4666-8666-666666666803',
    '66666666-6666-4666-8666-666666666601', '66666666-6666-4666-8666-666666666702',
    '44444444-4444-4444-8444-444444444402', 'Aula 03', 3,
    'Aula 03: Inviolabilidade Domiciliar e Sigilos',
    'Conceito amplo de casa para fins penais/constitucionais, hipóteses de ingresso sem mandado (flagrante delito, desastre, prestar socorro) e reserva de jurisdição na interceptação telefônica.',
    38, 2280, 150, false, 3
  ),
  (
    '66666666-6666-4666-8666-666666666804',
    '66666666-6666-4666-8666-666666666601', '66666666-6666-4666-8666-666666666702',
    '44444444-4444-4444-8444-444444444403', 'Aula 04', 4,
    'Aula 04: Remédios Constitucionais: Habeas Corpus e Habeas Data',
    'Análise detalhada do art. 5º, incisos LXVIII e LXXII da CF/88. Diferenciação entre tutela da liberdade de locomoção (HC) e direito de acesso/retificação de dados pessoais constantes em registros públicos (HD). Súmula 691 do STF e Súmula 2 do STJ.',
    42, 2520, 150, false, 4
  ),
  (
    '66666666-6666-4666-8666-666666666805',
    '66666666-6666-4666-8666-666666666601', '66666666-6666-4666-8666-666666666702',
    '44444444-4444-4444-8444-444444444403', 'Aula 05', 5,
    'Aula 05: Mandado de Segurança e Ação Popular',
    'Direito líquido e certo não amparado por HC ou HD, prazo decadencial de 120 dias, legitimidade do MS Coletivo e requisitos da Ação Popular pelo cidadão.',
    45, 2700, 150, false, 5
  ),
  (
    '66666666-6666-4666-8666-666666666806',
    '66666666-6666-4666-8666-666666666601', '66666666-6666-4666-8666-666666666702',
    '44444444-4444-4444-8444-444444444403', 'Aula 06', 6,
    'Aula 06: Resolução de 20 Questões Comentadas Cebraspe',
    'Bateria intensiva de fixação sobre Direitos Individuais e Remédios Constitucionais com foco em pegadinhas recorrentes do Cebraspe.',
    50, 3000, 200, false, 6
  )
ON CONFLICT (id) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  resumo_teorico = EXCLUDED.resumo_teorico,
  duracao_minutos = EXCLUDED.duracao_minutos;

-- Anexos da Aula 04 (`aulas.html`)
INSERT INTO public.aula_anexos (id, aula_id, titulo, tipo_arquivo, tamanho_label, paginas, ordem)
VALUES
  ('66666666-6666-4666-8666-666666666901', '66666666-6666-4666-8666-666666666804', 'Apostila PDF — Remédios Constitucionais Esquematizados', 'pdf', '4.2 MB', 28, 1),
  ('66666666-6666-4666-8666-666666666902', '66666666-6666-4666-8666-666666666804', 'Mapa Mental — Quadro Comparativo HC x HD x MS x MI x AP', 'mapa_mental', '1.8 MB', 4, 2),
  ('66666666-6666-4666-8666-666666666903', '66666666-6666-4666-8666-666666666804', 'Slides da Videoaula (Anotações do Professor)', 'slides', '3.1 MB', 18, 3)
ON CONFLICT (id) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  tamanho_label = EXCLUDED.tamanho_label;

-- ============================================================================
-- 9. BIBLIOTECA DIGITAL DE MATERIAIS (8 Materiais Reais de `materiais.html`)
-- ============================================================================
INSERT INTO public.materiais (
  id, slug, titulo, descricao, categoria, disciplina_id, concurso_id,
  disciplina_slug, disciplina_nome, autor_nome, paginas, unidade_paginas,
  tamanho_bytes, tamanho_label, edicao_ano, destaque_semana
)
VALUES
  (
    '77777777-7777-4777-8777-777777777701',
    'direito-constitucional-esquematizado-2026',
    'Direito Constitucional Esquematizado 2026',
    'Material completo atualizado com a jurisprudência do STF de 2025/2026, quadros sinóticos ao final de cada capítulo e 150 questões gabaritadas do Cebraspe e FGV.',
    'apostila', '33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222201',
    'constitucional', 'Direito Constitucional', 'Prof. Roberto Vasconcelos',
    184, 'páginas', 14889779, '14.2 MB', 2026, true
  ),
  (
    '77777777-7777-4777-8777-777777777702',
    'mapas-mentais-remedios-constitucionais',
    'Mapas Mentais: Remédios Constitucionais (HC, HD, MS, MI)',
    'Coleção visual de alta retenção com gatilhos de memória, legitimados ativos/passivos e súmulas do STF aplicáveis a cada remédio constitucional.',
    'mapa', '33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222201',
    'constitucional', 'Direito Constitucional', 'Equipe Pedagógica Agon',
    12, 'pranchas', 8808038, '8.4 MB', 2026, false
  ),
  (
    '77777777-7777-4777-8777-777777777703',
    'resumo-express-atos-administrativos-poderes',
    'Resumo Express: Atos Administrativos & Poderes da Administração',
    'Síntese reta ao ponto sobre requisitos (CO-FI-FO-MO-OB), atributos (PATI), espécies, anulação, revogação e cassação de atos administrativos.',
    'resumo', '33333333-3333-4333-8333-333333333302', '22222222-2222-4222-8222-222222222201',
    'administrativo', 'Direito Administrativo', 'Profª. Camila Duarte',
    36, 'páginas', 3250585, '3.1 MB', 2026, false
  ),
  (
    '77777777-7777-4777-8777-777777777704',
    'lei-8112-1990-esquematizada-sumulas',
    'Lei 8.112/1990 Esquematizada com Súmulas Vinculantes',
    'Regime Jurídico dos Servidores Públicos Civis da União artigo por artigo com grifos nos termos mais cobrados em prova e remissão às súmulas do STF e STJ.',
    'lei', '33333333-3333-4333-8333-333333333302', '22222222-2222-4222-8222-222222222201',
    'administrativo', 'Direito Administrativo', 'Equipe Pedagógica Agon',
    92, 'páginas', 6081740, '5.8 MB', 2026, false
  ),
  (
    '77777777-7777-4777-8777-777777777705',
    'manual-pratico-sintaxe-concordancia-regencia',
    'Manual Prático de Sintaxe, Concordância e Regência Verbal',
    'Guia definitivo para gabaritar Português na FGV, Cebraspe e Vunesp, com casos especiais de crase, colocação pronominal e reescrita de frases.',
    'apostila', '33333333-3333-4333-8333-333333333303', '22222222-2222-4222-8222-222222222202',
    'portugues', 'Língua Portuguesa', 'Prof. Carlos Eduardo',
    142, 'páginas', 10171187, '9.7 MB', 2026, false
  ),
  (
    '77777777-7777-4777-8777-777777777706',
    'guia-redes-protocolos-tcpip-seguranca',
    'Guia de Redes, Protocolos TCP/IP & Segurança da Informação',
    'Revisão técnica acelerada de portas lógicas, DNS, DHCP, HTTPS, Criptografia Simétrica/Assimétrica, Malware e ataques DDoS/Phishing para carreiras policiais.',
    'resumo', '33333333-3333-4333-8333-333333333305', '22222222-2222-4222-8222-222222222201',
    'informatica', 'Informática & TI', 'Equipe Pedagógica Agon',
    68, 'páginas', 4718592, '4.5 MB', 2026, false
  ),
  (
    '77777777-7777-4777-8777-777777777707',
    'mapas-raciocinio-logico-tabelas-verdade-negacoes',
    'Mapas de Raciocínio Lógico: Tabelas Verdade & Negações',
    'Fórmulas visuais das Leis de De Morgan, Regra do MANÉ, Equivalências da Condicional e quantificadores lógicos (Todo, Algum e Nenhum).',
    'mapa', '33333333-3333-4333-8333-333333333304', '22222222-2222-4222-8222-222222222203',
    'raciocinio', 'Raciocínio Lógico', 'Prof. Fernando Costa',
    16, 'pranchas', 6501171, '6.2 MB', 2026, false
  ),
  (
    '77777777-7777-4777-8777-777777777708',
    'constituicao-federal-anotada-jurisprudencia-stf',
    'Constituição Federal Anotada com Jurisprudência do STF',
    'Texto constitucional consolidado até a última Emenda Constitucional com notas de rodapé indicando os artigos de maior incidência em provas de 2022 a 2026.',
    'lei', '33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222201',
    'constitucional', 'Direito Constitucional', 'Equipe Pedagógica Agon',
    320, 'páginas', 23488102, '22.4 MB', 2026, false
  )
ON CONFLICT (slug) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  descricao = EXCLUDED.descricao,
  paginas = EXCLUDED.paginas,
  tamanho_label = EXCLUDED.tamanho_label,
  destaque_semana = EXCLUDED.destaque_semana;

-- ============================================================================
-- 10. SIMULADOS OFICIAIS (`simulados.html`)
-- ============================================================================
INSERT INTO public.simulados (
  id, slug, codigo, titulo, subtitulo, descricao, concurso_id, banca_id,
  concurso_sigla, banca_nome, modalidade, regra_pontuacao, fator_penalidade,
  total_questoes, duracao_minutos, nota_maxima, nota_corte_estimada, xp_conclusao, total_participantes
)
VALUES
  (
    '88888888-8888-4888-8888-888888888801',
    'simulado-geral-pf-agente', 'SIM-PF-01',
    'Simulado Geral - PF Agente',
    'Polícia Federal • Padrão Oficial Cebraspe',
    'Banca Cebraspe (Certo/Errado — 1 errada anula 1 certa). Abrange Blocos I, II e III com foco em Informática, Contabilidade e Direito.',
    '22222222-2222-4222-8222-222222222201', '11111111-1111-4111-8111-111111111101',
    'pf', 'Cebraspe', 'certo_errado', 'cebraspe_1x1', 1.00,
    120, 270, 120.00, 78.00, 450, 3480
  ),
  (
    '88888888-8888-4888-8888-888888888802',
    'simulado-especifico-auditor-rfb', 'SIM-RFB-01',
    'Simulado Específico - Auditor',
    'Receita Federal • Padrão FGV',
    'Banca FGV (Múltipla Escolha). Foco em Direito Tributário, Legislação Aduaneira, Contabilidade Geral e Língua Portuguesa.',
    '22222222-2222-4222-8222-222222222202', '11111111-1111-4111-8111-111111111102',
    'rfb', 'FGV', 'multipla_escolha', 'padrao', 0.00,
    80, 180, 80.00, 62.00, 400, 1890
  ),
  (
    '88888888-8888-4888-8888-888888888803',
    'simulado-tjsp-escrevente', 'SIM-TJSP-01',
    'Simulado TJSP - Escrevente',
    'Tribunal de Justiça de SP • Padrão Vunesp',
    'Banca Vunesp (Múltipla Escolha). Bloco I (Português), Bloco II (Direito e Normas da Corregedoria) e Bloco III (Informática e Raciocínio Lógico).',
    '22222222-2222-4222-8222-222222222203', '11111111-1111-4111-8111-111111111103',
    'tjsp', 'Vunesp', 'multipla_escolha', 'padrao', 0.00,
    100, 240, 100.00, 82.00, 350, 2640
  )
ON CONFLICT (slug) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  descricao = EXCLUDED.descricao,
  total_questoes = EXCLUDED.total_questoes,
  duracao_minutos = EXCLUDED.duracao_minutos,
  total_participantes = EXCLUDED.total_participantes;

-- Vincula as 3 questões reais aos simulados
INSERT INTO public.simulado_questoes (simulado_id, questao_id, ordem, bloco, peso, anulavel_por_erro)
VALUES
  ('88888888-8888-4888-8888-888888888801', '55555555-5555-4555-8555-555555555501', 1, 'Bloco III - Direito', 1.00, true),
  ('88888888-8888-4888-8888-888888888802', '55555555-5555-4555-8555-555555555502', 1, 'Bloco I - Linguagens', 1.00, false),
  ('88888888-8888-4888-8888-888888888803', '55555555-5555-4555-8555-555555555503', 1, 'Bloco III - Raciocínio Lógico', 1.00, false)
ON CONFLICT (simulado_id, questao_id) DO NOTHING;

-- ============================================================================
-- 11. TABELA DE NÍVEIS DE GAMIFICAÇÃO (1 a 20 — `conquistas.html`)
-- ============================================================================
INSERT INTO public.niveis (nivel, titulo, xp_minimo, xp_proximo_nivel, icone, cor_badge)
VALUES
  (1,  'Iniciante da Jornada',     0,     100,   'fa-seedling',     'blue'),
  (2,  'Leitor de Editais',        100,   220,   'fa-file-lines',   'blue'),
  (3,  'Estudante Constante',      220,   360,   'fa-book-open',    'blue'),
  (4,  'Praticante de Questões',   360,   520,   'fa-list-check',   'blue'),
  (5,  'Guardião da Rotina',       520,   700,   'fa-clock',        'green'),
  (6,  'Analista de Bancas',       700,   850,   'fa-magnifying-glass', 'green'),
  (7,  'Estrategista de Provas',   850,   980,   'fa-chess-knight', 'green'),
  (8,  'Dominador da Lei Seca',    980,   1080,  'fa-scale-balanced','cyan'),
  (9,  'Resiliente',               1080,  1200,  'fa-shield',       'cyan'),
  (10, 'Focado',                   1200,  1500,  'fa-bullseye',     'blue'),
  (11, 'Determinado',              1500,  1800,  'fa-fire',         'orange'),
  (12, 'Concurseiro Dedicado',     1800,  2500,  'fa-medal',        'blue'),
  (13, 'Mestre dos Concursos',     2500,  3400,  'fa-crown',        'purple'),
  (14, 'Especialista de Elite',    3400,  4500,  'fa-award',        'purple'),
  (15, 'Mentor da Turma',          4500,  5800,  'fa-graduation-cap','purple'),
  (16, 'Veterano de Corte',        5800,  7300,  'fa-star',         'orange'),
  (17, 'Imbatível nas Bancas',     7300,  9000,  'fa-bolt',         'orange'),
  (18, 'Aprovado Virtual',         9000,  11000, 'fa-trophy',       'green'),
  (19, 'Nomeado de Honra',         11000, 13500, 'fa-gem',          'cyan'),
  (20, 'Lenda do Diário Oficial',  13500, 20000, 'fa-crown',        'orange')
ON CONFLICT (nivel) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  xp_minimo = EXCLUDED.xp_minimo,
  xp_proximo_nivel = EXCLUDED.xp_proximo_nivel;

-- ============================================================================
-- 12. TEMPORADA ATIVA DE RANKING
-- ============================================================================
INSERT INTO public.temporadas (id, codigo, nome, descricao, data_inicio, data_fim, ativa)
VALUES (
  '99999999-9999-4999-8999-999999999901',
  '2026-OUTUBRO',
  'Temporada Outubro 2026',
  'Ranking oficial de XP dos concurseiros ativos na plataforma Agon.',
  '2026-10-01',
  '2026-12-31',
  true
)
ON CONFLICT (codigo) DO UPDATE SET
  nome = EXCLUDED.nome,
  ativa = EXCLUDED.ativa;

-- ============================================================================
-- 13. CONQUISTAS / BADGES (6 Badges de `conquistas.html`)
-- ============================================================================
INSERT INTO public.conquistas (
  id, slug, titulo, descricao_curta, descricao_detalhada,
  icone, cor_tema, xp_recompensa, regra_tipo, meta_valor, unidade_meta, ordem
)
VALUES
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
    'foco_total', 'Foco Total', '7 dias seguidos',
    'Estude por 7 dias consecutivos sem interromper sua sequência diária.',
    'fa-fire', 'orange', 250, 'streak_dias', 7, 'dias', 1
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa02',
    'estudioso', 'Estudioso', '40 horas de estudo',
    'Acumule 40 horas líquidas de estudos registradas na plataforma.',
    'fa-book', 'blue', 300, 'horas_estudo', 40, 'horas', 2
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa03',
    'centuriao', 'Centurião', '100 questões resolvidas',
    'Resolva 100 questões de concursos públicos no banco de questões.',
    'fa-check-double', 'green', 200, 'questoes_resolvidas', 100, 'questões', 3
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa04',
    'mestre', 'Mestre', '90% em simulado',
    'Alcance 90% ou mais de aproveitamento em um simulado oficial completo.',
    'fa-crown', 'purple', 600, 'nota_simulado', 90, '%', 4
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa05',
    'premium', 'Premium', 'Assinante Agon Pro',
    'Desbloqueie recursos ilimitados tornando-se membro Agon Pro.',
    'fa-gem', 'cyan', 400, 'assinatura_ativa', 1, 'assinatura', 5
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa06',
    'maratonista', 'Maratonista', '30 dias seguidos',
    'Mantenha uma sequência ininterrupta de 30 dias de estudos.',
    'fa-infinity', 'orange', 500, 'streak_dias', 30, 'dias', 6
  )
ON CONFLICT (slug) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  descricao_curta = EXCLUDED.descricao_curta,
  descricao_detalhada = EXCLUDED.descricao_detalhada,
  xp_recompensa = EXCLUDED.xp_recompensa,
  meta_valor = EXCLUDED.meta_valor;

-- ============================================================================
-- 14. SALAS DE ESTUDO AO VIVO — POMODORO (`comunidade.html`)
-- ============================================================================
INSERT INTO public.comunidade_salas_estudo (
  id, slug, nome, descricao, concurso_id, ciclo_pomodoro_minutos, pausa_minutos, participantes_online_base
)
VALUES
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01',
    'sala-pf-foco-total', 'Sala PF — Foco Total',
    'Estude em silêncio com áudio ambiente e cronômetro Pomodoro sincronizado 50/10.',
    '22222222-2222-4222-8222-222222222201', 50, 10, 32
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb02',
    'sala-receita-tjsp', 'Sala Receita & TJSP',
    'Sala dedicada aos concurseiros das carreiras Fiscal e de Tribunais.',
    '22222222-2222-4222-8222-222222222202', 50, 10, 19
  )
ON CONFLICT (slug) DO UPDATE SET
  nome = EXCLUDED.nome,
  participantes_online_base = EXCLUDED.participantes_online_base;

-- ============================================================================
-- 15. PLANOS DE ASSINATURA (`configuracoes.html` e `home.html`)
-- ============================================================================
INSERT INTO public.planos_assinatura (
  id, codigo, nome, descricao, periodicidade, preco_mensal_equivalente, preco_total_cobranca,
  limite_questoes_dia, limite_mensagens_zuka_dia, acesso_simulados_ilimitados,
  acesso_videoaulas_completas, acesso_materiais_pdf, recursos_json, destaque
)
VALUES
  (
    'cccccccc-cccc-4ccc-8ccc-cccccccccc01',
    'gratuito', 'Agon Gratuito',
    'Ideal para conhecer a metodologia Agon e começar sua rotina diária.',
    'vitalicio_gratuito', 0.00, 0.00,
    20, 5, false, false, false,
    '["20 questões comentadas por dia", "Diagnóstico básico de desempenho", "Acesso à Comunidade Agon", "5 dúvidas diárias na Zuka IA"]'::jsonb,
    false
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-cccccccccc02',
    'pro_mensal', 'Agon Pro Mensal',
    'Flexibilidade total mês a mês com acesso irrestrito à Zuka IA e simulados.',
    'mensal', 59.90, 59.90,
    NULL, NULL, true, true, true,
    '["Questões e cadernos ilimitados", "Zuka IA Tutor 24/7 ilimitada", "Simulados oficiais e gerados por IA", "Apostilas PDF e Mapas Mentais"]'::jsonb,
    false
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-cccccccccc03',
    'pro_anual', 'Agon Pro Anual',
    'O plano preferido dos aprovados: economia máxima e preparação completa até a posse.',
    'anual', 39.90, 478.80,
    NULL, NULL, true, true, true,
    '["Questões ilimitadas comentadas", "Simulados semanais com ranking", "Acesso total à Zuka IA Tutor 24/7", "Download de PDFs e Mapas Mentais", "Garantia incondicional de 7 dias"]'::jsonb,
    true
  )
ON CONFLICT (codigo) DO UPDATE SET
  nome = EXCLUDED.nome,
  preco_mensal_equivalente = EXCLUDED.preco_mensal_equivalente,
  preco_total_cobranca = EXCLUDED.preco_total_cobranca,
  recursos_json = EXCLUDED.recursos_json;

-- ============================================================================
-- 16. ROADMAP DE LANÇAMENTOS & MÓDULOS (`em-breve.html`)
-- ============================================================================
INSERT INTO public.roadmap_fases (numero_fase, titulo, descricao, status, progresso_percentual, previsao_entrega, ordem)
VALUES
  (1, 'Fase 1: Banco de Questões & IA Tutor', 'Mais de 50 mil questões comentadas e integração ao vivo com a tutora Zuka IA.', 'concluida', 100, 'Concluído', 1),
  (2, 'Fase 2: Simulados & Rankings', 'Provas cronometradas no padrão Cebraspe/FGV/Vunesp e gamificação por temporadas.', 'disponivel', 100, 'Disponível', 2),
  (3, 'Fase 3: Videoaulas & Materiais', 'Player interativo de videoaulas em alta definição, transcrição sincronizada e Agon Reader.', 'em_desenvolvimento', 78, 'Novembro 2026', 3),
  (4, 'Fase 4: Ciclos Inteligentes', 'Reagendamento automático de metas semanais baseado nas taxas de erro do aluno.', 'proxima', 35, 'Dezembro 2026', 4)
ON CONFLICT (numero_fase) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  status = EXCLUDED.status,
  progresso_percentual = EXCLUDED.progresso_percentual;

INSERT INTO public.roadmap_modulos (
  slug, badge_titulo, titulo, descricao, icone, progresso_desenvolvimento,
  previsao_lancamento, status_etapa, entregaveis_json, total_inscritos_espera
)
VALUES
  (
    'aulas', 'MÓDULO DE VIDEOAULAS', 'Aulas & Trilhas em Vídeo estão chegando!',
    'Estamos gravando e organizando aulas diretas ao ponto, sem enrolação, integradas com mapas mentais e questões de fixação ao final de cada bloco.',
    'fa-circle-play', 82, 'Novembro 2026', 'Edição Final & Transcrição por IA',
    '[{"item": "Player inteligente com velocidade até 2.5x e marcação de tempo", "status": "concluido"}, {"item": "Resumo automático e transcrição pesquisável por aula", "status": "concluido"}, {"item": "Integração direta de dúvidas do minuto do vídeo com a Zuka IA", "status": "em_andamento"}, {"item": "Emissão automática de certificado de conclusão por disciplina", "status": "pendente"}]'::jsonb,
    418
  ),
  (
    'planos-estudo', 'CRONOGRAMA INTELIGENTE', 'Planos de Estudo Adaptativos em Fase Final',
    'Seu edital verticalizado conectado ao método de repetição espaçada SM-2 (24h, 7d e 30d).',
    'fa-calendar-check', 78, 'Novembro 2026', 'Testes Internos & Revisão Pedagógica',
    '[{"item": "Edital verticalizado interativo para PF, RFB, TJ-SP e INSS", "status": "concluido"}, {"item": "Checklist diário com cálculo automático de horas líquidas", "status": "concluido"}, {"item": "Algoritmo SuperMemo SM-2 de revisões espaçadas", "status": "em_andamento"}, {"item": "Reorganização automática da semana em caso de imprevistos", "status": "pendente"}]'::jsonb,
    342
  ),
  (
    'materiais', 'BIBLIOTECA DIGITAL', 'Apostilas PDF & Mapas Mentais Esquematizados',
    'Materiais enxutos diagramados para leitura rápida com o visualizador integrado Agon Reader.',
    'fa-folder-open', 85, 'Novembro 2026', 'Diagramação Final de Mapas Mentais',
    '[{"item": "Apostilas esquematizadas com grifos dos artigos mais cobrados", "status": "concluido"}, {"item": "Leitor rápido Agon Reader sem sair da plataforma", "status": "concluido"}, {"item": "Coleção de Mapas Mentais em alta resolução para impressão", "status": "em_andamento"}, {"item": "Sincronização da última página lida entre dispositivos", "status": "pendente"}]'::jsonb,
    295
  ),
  (
    'configuracoes', 'CENTRAL DA CONTA', 'Gerenciamento Avançado de Perfil e Assinatura',
    'Personalize sua experiência de estudo, notificações diárias, segurança 2FA e histórico de faturas.',
    'fa-Sliders', 90, 'Novembro 2026', 'Homologação de Segurança',
    '[{"item": "Personalização de metas, foto de perfil e tema claro/escuro", "status": "concluido"}, {"item": "Configuração de lembretes diários de estudo e alertas de editais", "status": "concluido"}, {"item": "Autenticação em duas etapas (2FA) e gestão de sessões ativas", "status": "em_andamento"}, {"item": "Portal de autoatendimento de faturas e upgrade de plano", "status": "pendente"}]'::jsonb,
    180
  )
ON CONFLICT (slug) DO UPDATE SET
  titulo = EXCLUDED.titulo,
  progresso_desenvolvimento = EXCLUDED.progresso_desenvolvimento,
  entregaveis_json = EXCLUDED.entregaveis_json;

-- ============================================================================
-- 17. DEPOIMENTOS DE APROVADOS (`home.html`)
-- ============================================================================
INSERT INTO public.depoimentos (
  id, concurso_id, nome_aluno, cargo_aprovado, cidade_uf, avatar_url, texto, nota_estrelas, destaque_home, aprovado_moderacao, ordem
)
VALUES
  (
    'dddddddd-dddd-4ddd-8ddd-dddddddddd01',
    '22222222-2222-4222-8222-222222222201',
    'Lucas Vasconcelos',
    'Aprovado Polícia Federal',
    'Brasília, DF',
    'assets/img/perfil.jpg',
    'O IA Tutor me fez economizar horas de pesquisa em fóruns confusos. Quando errei uma pegadinha sobre remédios constitucionais, perguntei à IA e ela me deu o mnemônico exato que caiu na prova da Polícia Federal!',
    5, true, true, 1
  ),
  (
    'dddddddd-dddd-4ddd-8ddd-dddddddddd02',
    '22222222-2222-4222-8222-222222222203',
    'Beatriz Nogueira',
    'Aprovada TJ-SP (Escrevente)',
    'São Paulo, SP',
    'assets/img/perfil.jpg',
    'O edital verticalizado aliado às estatísticas por assunto mudou completamente meu jeito de revisar. Saí de 64% para 89% de acerto na Vunesp em menos de três meses.',
    5, true, true, 2
  ),
  (
    'dddddddd-dddd-4ddd-8ddd-dddddddddd03',
    '22222222-2222-4222-8222-222222222202',
    'Rafael Albuquerque',
    'Aprovado Receita Federal',
    'Curitiba, PR',
    'assets/img/perfil.jpg',
    'Os simulados no padrão FGV e o sistema de repetição espaçada 24h/7d/30d foram decisivos para manter a retenção de Direito Tributário e Contabilidade até o dia da prova.',
    5, true, true, 3
  )
ON CONFLICT (id) DO UPDATE SET
  texto = EXCLUDED.texto,
  cargo_aprovado = EXCLUDED.cargo_aprovado,
  aprovado_moderacao = EXCLUDED.aprovado_moderacao;

-- ============================================================================
-- 18. FLASHCARDS OFICIAIS DO CATÁLOGO AGON
-- ============================================================================
INSERT INTO public.flashcards (
  id, user_id, disciplina_id, assunto_id, disciplina_nome, assunto_nome,
  frente, verso, mnemonico, oficial_agon
)
VALUES
  (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01',
    NULL,
    '33333333-3333-4333-8333-333333333301',
    '44444444-4444-4444-8444-444444444401',
    'Direito Constitucional', 'Princípios Fundamentais',
    'Quais são os 5 Fundamentos da República Federativa do Brasil (Art. 1º da CF/88)?',
    'I - Soberania; II - Cidadania; III - Dignidade da pessoa humana; IV - Valores sociais do trabalho e da livre iniciativa; V - Pluralismo político.',
    'SO-CI-DI-VA-PLU',
    true
  ),
  (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee02',
    NULL,
    '33333333-3333-4333-8333-333333333302',
    '44444444-4444-4444-8444-444444444405',
    'Direito Administrativo', 'Atos Administrativos',
    'Quais são os 5 elementos/requisitos de validade do Ato Administrativo e seus 4 atributos?',
    'Requisitos: Competência, Finalidade, Forma, Motivo e Objeto. Atributos: Presunção de legitimidade/veracidade, Autoexecutoriedade, Tipicidade e Imperatividade.',
    'Requisitos: CO-FI-FO-MO-OB | Atributos: P-A-T-I',
    true
  ),
  (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee03',
    NULL,
    '33333333-3333-4333-8333-333333333304',
    '44444444-4444-4444-8444-444444444411',
    'Raciocínio Lógico', 'Equivalências e Negação Lógica',
    'Como se faz a NEGAÇÃO e as duas EQUIVALÊNCIAS da condicional (P → Q)?',
    'Negação: P ∧ ~Q (Mantém a primeira E nega a segunda). Equivalência 1 (Contrapositiva): ~Q → ~P. Equivalência 2 (Disjunção): ~P ∨ Q.',
    'Negação: MANÉ | Equivalência 2: NEYMAR (~P ou Q)',
    true
  )
ON CONFLICT (id) DO UPDATE SET
  frente = EXCLUDED.frente,
  verso = EXCLUDED.verso,
  mnemonico = EXCLUDED.mnemonico;
