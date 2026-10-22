-- ============================================================================
-- AGON — Migração 010: Extensões de Usuários, Preferências, Notificações,
--                      Segurança de Autenticação e Planos/Assinaturas
-- ============================================================================
-- Descrição: Estende `public.usuarios` sem quebrar nenhuma coluna existente e
-- cria as tabelas de suporte para `configuracoes.html`, `login.html`,
-- `cadastro.html` e o sino de notificações do topo de todas as páginas:
-- `usuario_preferencias`, `notificacoes`, `tokens_redefinicao_senha`,
-- `sessoes_usuario`, `tentativas_login`, `aceites_termos`, `planos_assinatura`,
-- `assinaturas` e `faturas`.
-- ============================================================================

-- ============================================================================
-- 1. EXTENSÃO NÃO-DESTRUTIVA DE `public.usuarios`
-- ============================================================================
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE,
  ADD COLUMN IF NOT EXISTS concurso_alvo TEXT DEFAULT 'Geral',
  ADD COLUMN IF NOT EXISTS horas_semanais NUMERIC(5,2) NOT NULL DEFAULT 15.00,
  ADD COLUMN IF NOT EXISTS cidade_uf TEXT DEFAULT 'São Paulo, SP',
  ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT 'Estudando com constância até a posse pública!',
  ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '/assets/img/perfil.jpg',
  ADD COLUMN IF NOT EXISTS avatar_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS concurso_foco_id UUID REFERENCES public.concursos(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cargo_desejado TEXT DEFAULT 'Polícia Federal — Agente',
  ADD COLUMN IF NOT EXISTS nivel_atual INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS streak_atual_dias INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS maior_streak_dias INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ultimo_dia_estudo DATE,
  ADD COLUMN IF NOT EXISTS meta_horas_semanal NUMERIC(5,2) NOT NULL DEFAULT 15.00,
  ADD COLUMN IF NOT EXISTS meta_horas_diaria NUMERIC(4,2) NOT NULL DEFAULT 3.50,
  ADD COLUMN IF NOT EXISTS onboarding_concluido BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS conta_ativa BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS ultimo_login_em TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_usuarios_concurso_foco ON public.usuarios(concurso_foco_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_pontos_xp ON public.usuarios(pontos_gamificacao DESC);

-- ============================================================================
-- 2. AJUSTE COMPATÍVEL EM `student_topic_stats`
-- ============================================================================
-- Adiciona colunas usadas por `services/database.js` (`total_acertos`, `total_erros`,
-- `tempo_total_segundos`, `ultima_atividade`) mantendo as originais intactas, e
-- alinha a constraint de `classificacao_dificuldade`.
ALTER TABLE public.student_topic_stats
  ADD COLUMN IF NOT EXISTS total_acertos INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_erros INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tempo_total_segundos INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ultima_atividade TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.student_topic_stats
  DROP CONSTRAINT IF EXISTS student_topic_stats_classificacao_dificuldade_check;

ALTER TABLE public.student_topic_stats
  ADD CONSTRAINT student_topic_stats_classificacao_dificuldade_check
  CHECK (classificacao_dificuldade IN (
    'alta',
    'moderada',
    'em_desenvolvimento',
    'bom_desempenho',
    'dados_insuficientes'
  ));

-- ============================================================================
-- 3. TABELA: usuario_preferencias (`configuracoes.html` e modal de Perfil)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.usuario_preferencias (
  user_id TEXT PRIMARY KEY REFERENCES public.usuarios(id) ON DELETE CASCADE,
  tema TEXT NOT NULL DEFAULT 'light'
    CHECK (tema IN ('light', 'dark', 'system')),
  tamanho_fonte_questoes TEXT NOT NULL DEFAULT 'padrao'
    CHECK (tamanho_fonte_questoes IN ('compacta', 'padrao', 'grande')),
  mostrar_cronometro_questoes BOOLEAN NOT NULL DEFAULT true,
  ocultar_comentarios_automaticamente BOOLEAN NOT NULL DEFAULT false,
  notif_lembrete_diario BOOLEAN NOT NULL DEFAULT true,
  horario_lembrete_diario TIME NOT NULL DEFAULT '19:00:00',
  notif_novos_simulados_editais BOOLEAN NOT NULL DEFAULT true,
  notif_resumo_semanal_email BOOLEAN NOT NULL DEFAULT false,
  notif_push_navegador BOOLEAN NOT NULL DEFAULT true,
  notif_interacoes_comunidade BOOLEAN NOT NULL DEFAULT true,
  autenticacao_2fa_ativa BOOLEAN NOT NULL DEFAULT false,
  metodo_2fa TEXT DEFAULT 'email'
    CHECK (metodo_2fa IN ('email', 'totp_app', 'sms')),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_usuario_preferencias_updated_at ON public.usuario_preferencias;
CREATE TRIGGER trg_usuario_preferencias_updated_at
BEFORE UPDATE ON public.usuario_preferencias
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. TABELA: notificacoes (Dropdown do sino na topbar de todas as páginas)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notificacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL DEFAULT 'sistema'
    CHECK (tipo IN ('simulado', 'conquista', 'meta_diaria', 'comunidade', 'edital', 'assinatura', 'sistema')),
  titulo TEXT NOT NULL,
  mensagem TEXT NOT NULL, -- Ex: 'Novo simulado da Polícia Federal disponível!'
  icone TEXT NOT NULL DEFAULT 'fa-bell',
  cor_tema TEXT NOT NULL DEFAULT 'blue'
    CHECK (cor_tema IN ('blue', 'green', 'orange', 'purple', 'red', 'cyan')),
  link_destino TEXT DEFAULT '/index',
  lida BOOLEAN NOT NULL DEFAULT false,
  lida_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notificacoes_user_lida ON public.notificacoes(user_id, lida, criado_em DESC);

-- ============================================================================
-- 5. TABELA: tokens_redefinicao_senha ("Esqueceu a senha?" em `login.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tokens_redefinicao_senha (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  token_hash TEXT UNIQUE NOT NULL,
  ip_solicitante TEXT,
  expira_em TIMESTAMPTZ NOT NULL,
  utilizado_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tokens_redefinicao_user ON public.tokens_redefinicao_senha(user_id, expira_em DESC);

-- ============================================================================
-- 6. TABELA: sessoes_usuario (Dispositivos Conectados em `configuracoes.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.sessoes_usuario (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  session_token_id TEXT,
  dispositivo_nome TEXT NOT NULL DEFAULT 'Windows PC • Google Chrome',
  sistema_operacional TEXT DEFAULT 'Windows',
  navegador TEXT DEFAULT 'Chrome',
  tipo_dispositivo TEXT NOT NULL DEFAULT 'desktop'
    CHECK (tipo_dispositivo IN ('desktop', 'mobile', 'tablet')),
  localizacao TEXT DEFAULT 'São Paulo, Brasil',
  ip_address TEXT,
  manter_conectado BOOLEAN NOT NULL DEFAULT true,
  sessao_atual BOOLEAN NOT NULL DEFAULT false,
  revogada BOOLEAN NOT NULL DEFAULT false,
  revogada_em TIMESTAMPTZ,
  ultimo_acesso_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expira_em TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessoes_usuario_user ON public.sessoes_usuario(user_id, revogada, ultimo_acesso_em DESC);

-- ============================================================================
-- 7. TABELA: tentativas_login (Auditoria e Rate-Limit de segurança no Login)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tentativas_login (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  user_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
  sucesso BOOLEAN NOT NULL DEFAULT false,
  motivo_falha TEXT,
  ip_address TEXT,
  user_agent TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tentativas_login_email_data ON public.tentativas_login(email, criado_em DESC);

-- ============================================================================
-- 8. TABELA: aceites_termos (Auditoria LGPD do checkbox em `cadastro.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.aceites_termos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  versao_termos TEXT NOT NULL DEFAULT 'v1.0-2026',
  versao_privacidade TEXT NOT NULL DEFAULT 'v1.0-2026',
  ip_address TEXT,
  user_agent TEXT,
  aceito_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aceites_termos_user ON public.aceites_termos(user_id, aceito_em DESC);

-- ============================================================================
-- 9. TABELA: planos_assinatura (Catálogo de Planos: Gratuito, Pro Mensal, Pro Anual)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.planos_assinatura (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT UNIQUE NOT NULL, -- 'gratuito', 'pro_mensal', 'pro_anual'
  nome TEXT NOT NULL, -- 'Agon Gratuito', 'Agon Pro Mensal', 'Agon Pro Anual'
  descricao TEXT,
  periodicidade TEXT NOT NULL DEFAULT 'anual'
    CHECK (periodicidade IN ('vitalicio_gratuito', 'mensal', 'trimestral', 'semestral', 'anual')),
  preco_mensal_equivalente NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  preco_total_cobranca NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  limite_questoes_dia INTEGER, -- NULL = ilimitado
  limite_mensagens_zuka_dia INTEGER, -- NULL = ilimitado
  acesso_simulados_ilimitados BOOLEAN NOT NULL DEFAULT false,
  acesso_videoaulas_completas BOOLEAN NOT NULL DEFAULT false,
  acesso_materiais_pdf BOOLEAN NOT NULL DEFAULT false,
  recursos_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  destaque BOOLEAN NOT NULL DEFAULT false,
  ativo BOOLEAN NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_planos_assinatura_updated_at ON public.planos_assinatura;
CREATE TRIGGER trg_planos_assinatura_updated_at
BEFORE UPDATE ON public.planos_assinatura
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 10. TABELA: assinaturas (Assinatura ativa e histórico do aluno)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.assinaturas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  plano_id UUID NOT NULL REFERENCES public.planos_assinatura(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'ativa'
    CHECK (status IN ('ativa', 'trial', 'inadimplente', 'cancelada', 'expirada')),
  valor_contratado NUMERIC(10,2) NOT NULL DEFAULT 39.90,
  metodo_pagamento TEXT DEFAULT 'cartao_credito'
    CHECK (metodo_pagamento IN ('gratuito', 'cartao_credito', 'pix', 'boleto')),
  cartao_bandeira TEXT DEFAULT 'Mastercard',
  cartao_ultimos4 TEXT DEFAULT '8492',
  cartao_validade TEXT DEFAULT '09/2029',
  inicio_vigencia_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  proxima_cobranca_em DATE,
  cancelada_em TIMESTAMPTZ,
  renovacao_automatica BOOLEAN NOT NULL DEFAULT true,
  gateway_subscription_id TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assinaturas_user_status ON public.assinaturas(user_id, status);

DROP TRIGGER IF EXISTS trg_assinaturas_updated_at ON public.assinaturas;
CREATE TRIGGER trg_assinaturas_updated_at
BEFORE UPDATE ON public.assinaturas
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 11. TABELA: faturas (Histórico de Faturas & Recibos PDF em `configuracoes.html`)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.faturas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assinatura_id UUID REFERENCES public.assinaturas(id) ON DELETE SET NULL,
  user_id TEXT NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  codigo_fatura TEXT UNIQUE NOT NULL,
  descricao TEXT NOT NULL DEFAULT 'Plano Agon Pro Anual',
  competencia_data DATE NOT NULL DEFAULT CURRENT_DATE,
  valor NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pago'
    CHECK (status IN ('pago', 'pendente', 'falhou', 'reembolsado', 'cancelado')),
  metodo_pagamento TEXT DEFAULT 'Cartão •••• 8492',
  recibo_pdf_url TEXT,
  pago_em TIMESTAMPTZ DEFAULT NOW(),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_faturas_user_data ON public.faturas(user_id, competencia_data DESC);
