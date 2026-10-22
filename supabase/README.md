# 🚀 Guia de Integração Supabase — AGON

Este diretório contém os scripts de migração SQL versionados e as instruções completas para conectar o **AGON** ao seu próprio projeto no **Supabase**.

---

## 📋 Passo a Passo para Configurar o Supabase

### 1. Criar o Projeto no Supabase
1. Acesse o [Supabase Dashboard](https://supabase.com/dashboard).
2. Clique em **"New Project"**.
3. Escolha o nome da organização, dê um nome ao projeto (ex: `agon-plataforma`) e defina uma senha forte para o banco de dados.
4. Selecione a região mais próxima (ex: `South America (São Paulo) - sa-east-1`).
5. Aguarde cerca de 1 a 2 minutos até que o projeto seja provisionado.

---

### 2. Obter as Credenciais da API
1. No menu lateral esquerdo do Supabase, clique no ícone de engrenagem ⚙️ **Project Settings**.
2. Clique na seção **API** (ou **API Keys**).
3. Copie os seguintes valores:
   - **Project URL**: (ex: `https://xyzcompany.supabase.co`)
   - **anon / public key**: chave pública para operações no cliente.
   - **service_role key**: chave secreta com privilégios de administração (mantenha em sigilo absoluto!).

---

### 3. Configurar as Variáveis de Ambiente no AGON
Abra o arquivo `.env` na raiz do projeto AGON e preencha:

```env
# Conexão Oficial Supabase
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua_chave_anonima_publica_aqui
SUPABASE_SERVICE_ROLE_KEY=sua_chave_service_role_secreta_aqui
```

> ⚠️ **Atenção:** Nunca compartilhe a chave `SUPABASE_SERVICE_ROLE_KEY` no frontend ou em repositórios públicos. Ela é utilizada estritamente no ambiente seguro do backend Node.js.

---

### 4. Executar as Migrações SQL

Você pode aplicar a estrutura do banco de dados de duas formas:

#### Opção A — Pelo Painel do Supabase (Mais Rápido e Fácil):
1. No painel do seu projeto Supabase, acesse a aba **SQL Editor** no menu lateral esquerdo.
2. Clique em **"New query"**.
3. Copie o conteúdo do arquivo [`migrations/20261022000001_initial_schema.sql`](./migrations/20261022000001_initial_schema.sql) e cole no editor.
4. Clique em **"Run"** (ou aperte `Ctrl + Enter`).
5. Crie uma nova query, copie o conteúdo de [`migrations/20261022000002_row_level_security.sql`](./migrations/20261022000002_row_level_security.sql), cole e execute clicando em **"Run"**.
6. Pronto! As 6 tabelas com índices, restrições e políticas de segurança RLS estarão ativas.

#### Opção B — Via Supabase CLI (Para Desenvolvedores):
```bash
# Vincular projeto remoto
npx supabase link --project-ref seu-project-ref

# Aplicar migrações
npx supabase db push
```

---

### 5. Configurar o Supabase Auth (E-mail e Senha)
1. No menu lateral, acesse **Authentication** > **Providers**.
2. Garanta que o provedor **Email** esteja habilitado (**Enabled**).
3. Se estiver em ambiente de desenvolvimento local e desejar desativar a confirmação obrigatória de e-mail:
   - Em **Authentication** > **URL Configuration**, verifique se a URL do site está apontando para `http://localhost:3500`.
   - Em **Authentication** > **Providers** > **Email**, você pode desmarcar temporariamente *"Confirm email"* para cadastros e logins imediatos sem envio de link no e-mail de teste.

---

### 6. Estrutura das Tabelas Criadas

| Tabela | Finalidade | Segurança RLS |
| :--- | :--- | :--- |
| `usuarios` | Perfis de alunos, pontuação e configurações | Privado (`auth.uid() = id`) |
| `question_attempts` | Histórico e tentativas de resolução de questões | Privado (`auth.uid() = user_id`) |
| `student_topic_stats` | Métricas agregadas por disciplina/assunto | Privado (`auth.uid() = user_id`) |
| `ai_conversations` | Conversas com a tutora Zuka IA | Privado (`auth.uid() = user_id`) |
| `ai_messages` | Mensagens do chat e contexto de questões | Privado (`auth.uid() = user_id`) |
| `study_recommendations` | Plano de estudos e recomendações geradas | Privado (`auth.uid() = user_id`) |

---

### 7. Inicialização do Projeto
No terminal do projeto AGON:

```bash
npm start
```

O console exibirá:
```
=========================================
🚀 Servidor Agon rodando em http://localhost:3500
🌐 Supabase Status: Conectado ao Supabase na Nuvem ⚡
🤖 Zuka IA: Ativa com Google Gemini ✨
=========================================
```
