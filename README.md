# Agon — Plataforma de Estudos com Supabase & Zuka IA

Plataforma educacional completa para concursos públicos com backend Node.js (Express), autenticação segura (Bcrypt + Sessões), banco de dados **Supabase (PostgreSQL Cloud com Row Level Security)**, persistência local para desenvolvimento offline e a **Zuka IA** — inteligência artificial tutora integrada com a API oficial do Google Gemini.

---

## ⚡ Infraestrutura Oficial: Supabase

A infraestrutura de banco de dados e autenticação do AGON utiliza o **Supabase**:
- **PostgreSQL com Row Level Security (RLS)** ativo em todas as tabelas.
- Políticas de acesso restritas: cada estudante só pode consultar e modificar seus próprios dados (`auth.uid() = user_id`).
- Migrações versionadas prontas para execução em [`supabase/migrations/`](./supabase/migrations/).
- Cliente oficial `@supabase/supabase-js` desacoplado na camada de serviços.
- Modo de fallback local transparente caso as chaves ainda não tenham sido configuradas no `.env`.

Para o guia detalhado de criação do projeto no Supabase e execução das migrações SQL, consulte:
👉 **[Guia Completo de Configuração do Supabase](./supabase/README.md)**

---

## 🤖 Zuka IA — Inteligência Artificial Educacional

A **Zuka IA** é a tutora educacional integrada à plataforma Agon, projetada para preparação de alto rendimento para concursos públicos (Cebraspe, FGV, Vunesp, FCC).

### Principais Recursos Implementados
1. **Chat Didático Funcional:** Tira dúvidas teóricas, explica passo a passo o porquê de alternativas estarem corretas ou incorretas, cria questões inéditas devidamente identificadas como `[Questão Inédita gerada pela Zuka IA]`.
2. **Contexto de Resolução de Questões:** Ao clicar em **"Explicar com Zuka IA"** em qualquer questão do Banco de Questões, a IA recebe o enunciado completo, alternativas, gabarito oficial cadastrado, comentário do professor e a resposta marcada pelo estudante.
3. **Aprendizado e Personalização Real:** Cada questão respondida é persistida com disciplina, assunto, resultado e tempo gasto no banco de dados. A IA e o sistema utilizam esse histórico para identificar fraquezas sem inventar estatísticas.
4. **Dashboard de Desempenho com Zuka IA:** 
   - Indicadores gerais (total respondidas, acertos, erros, taxa de aproveitamento, tempo médio por questão, evolução nos últimos 7 e 30 dias).
   - Comparativo por disciplina em gráfico interativo.
   - Mapa de dificuldades transparente com limiares definidos:
     - **Dificuldade Alta:** erro $\ge$ 60% (mínimo 5 respostas válidas).
     - **Dificuldade Moderada:** erro entre 35% e 59% (mínimo 5 respostas válidas).
     - **Bom Desempenho:** erro $<$ 35% (mínimo 5 respostas válidas).
     - **Dados Insuficientes:** menos de 5 respostas válidas.
   - Recomendações automáticas de estudo baseadas nos pontos críticos diagnosticados.
5. **Segurança e Isolamento:**
   - A chave de API (`GEMINI_API_KEY`) e as credenciais administrativas do Supabase nunca são expostas no frontend nem no repositório.
   - Rate limiting no servidor (máximo de 20 requisições por minuto por estudante).
   - Sanitização de entradas com limite de 4.000 caracteres contra injeção de instruções.
   - Isolamento total entre dados de estudantes diferentes via RLS e validações de sessão.
   - Mensagens claras e transparentes em caso de indisponibilidade ou ausência de chave (sem simulações falsas).

---

## 🔑 Configuração de Ambiente (.env)

Copie o arquivo `.env.example` para `.env` e preencha suas variáveis:

```env
PORT=3500
SESSION_SECRET=agon-secret-key-supabase-2026

# Supabase (Obtenha em: https://supabase.com/dashboard > Project Settings > API)
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua_chave_anonima_publica_aqui
SUPABASE_SERVICE_ROLE_KEY=sua_chave_service_role_secreta_aqui

# Inteligência Artificial - Zuka IA (Google Gemini oficial - obtenha em https://aistudio.google.com)
GEMINI_API_KEY=sua_chave_gemini_aqui
GEMINI_MODEL=gemini-flash-lite-latest
```

---

## 📁 Estrutura do Projeto

```text
Agon/
├── services/
│   ├── supabaseClient.js     # Cliente centralizado do Supabase (@supabase/supabase-js)
│   ├── database.js           # Camada unificada: Supabase Postgres + JSON Local persistente
│   ├── aiProvider.js         # Camada de abstração e provedor Google Gemini (REST API)
│   ├── zukaService.js        # Persona pedagógica, contexto de questões e recomendações
│   └── analyticsService.js   # Regras de cálculo, mapa de dificuldades e estatísticas
├── supabase/
│   ├── README.md             # Guia passo a passo de configuração no Supabase
│   └── migrations/           # Migrações SQL versionadas
│       ├── 20261022000001_initial_schema.sql       # Tabelas, índices, triggers e restrições
│       └── 20261022000002_row_level_security.sql   # Políticas de segurança Row Level Security (RLS)
├── data/
│   └── local_db.json         # Persistência local (questões, tentativas, histórico de conversas)
├── tests/
│   └── zuka.test.js          # Testes automatizados (cálculos, isolamento, Supabase e endpoints)
├── public/                   # Frontend Agon
│   ├── ia-tutor.html         # Painel e chat interativo com a Zuka IA
│   ├── questoes.html         # Banco de Questões integrado com registro e IA
│   ├── desempenho.html       # Dashboard de Desempenho com Zuka IA
│   ├── planos-estudo.html    # Plano de estudos inteligente
│   ├── css/ & js/            # Estilos e scripts Agon
│   └── assets/img/           # Imagens e logotipos (agon-white.png, etc.)
├── server.js                 # Servidor Express com APIs de Autenticação, Questões e Zuka IA
├── .env.example              # Modelo de variáveis de ambiente sem segredos
├── package.json              # Dependências e scripts de execução/testes
└── README.md                 # Documentação completa
```

---

## 🧪 Testes Automatizados

O projeto conta com uma suíte de testes automatizados para as regras críticas de cálculo, isolamento, integridade e endpoints:

```bash
npm test
```

Testes inclusos:
- Regras de classificação de dificuldade (Thresholds $\ge$ 60%, 35-59%, $<$ 35%, $<$ 5).
- Cálculo de estatísticas agregadas e tempo médio.
- Persistência e deduplicação de tentativas de questões.
- Isolamento estrito de dados entre estudantes.
- Higienização e limite de tamanho de entradas.
- Formatação do contexto com enunciado, alternativas e gabarito oficial.
- Tratamento seguro de erros de API e ausência de chave da IA.
- Verificação dos endpoints HTTP `/api/zuka/*`, `/api/desempenho/*` e `/api/supabase/status`.

---

## 🚀 Como Iniciar

1. **Instalar dependências:**
   ```bash
   npm install
   ```

2. **Executar o servidor:**
   ```bash
   npm start
   # ou npm run dev para recarregar automaticamente ao editar arquivos
   ```

3. **Acessar as páginas:**
   - **Aplicação Principal:** [http://localhost:3500](http://localhost:3500)
   - **Zuka IA (Tutor Inteligente):** [http://localhost:3500/ia-tutor.html](http://localhost:3500/ia-tutor.html)
   - **Banco de Questões:** [http://localhost:3500/questoes.html](http://localhost:3500/questoes.html)
   - **Desempenho com Zuka IA:** [http://localhost:3500/desempenho.html](http://localhost:3500/desempenho.html)
   - **Planos de Estudo:** [http://localhost:3500/planos-estudo.html](http://localhost:3500/planos-estudo.html)
