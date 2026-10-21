# Agon — Plataforma de Estudos

Plataforma completa de estudos com backend Node.js (Express), autenticação segura (Bcrypt + Sessões) e banco de dados **Google Firebase (Firestore)**.

---

## 📁 Estrutura de Pastas

```text
Agon/
├── public/                     # Arquivos do Frontend (HTML, CSS, JS, Assets)
│   ├── index.html / home.html  # Dashboard principal
│   ├── login.html              # Tela de Login (conectada à API)
│   ├── cadastro.html           # Tela de Cadastro (conectada à API)
│   ├── aulas.html              # Videoaulas e Player
│   ├── planos-estudo.html      # Cronograma e Ciclo de Estudos
│   ├── materiais.html          # PDFs, Resumos e Mapas Mentais
│   ├── estudos.html            # Trilhas de Estudo
│   ├── questoes.html           # Banco de Questões
│   ├── simulados.html          # Simulados
│   ├── desempenho.html         # Estatísticas & Gráficos
│   ├── ia-tutor.html           # IA Tutor
│   ├── comunidade.html         # Fórum & Comunidade
│   ├── conquistas.html         # Gamificação
│   ├── configuracoes.html      # Configurações do Usuário
│   ├── em-breve.html           # Lançamentos
│   ├── css/                    # styles.css
│   ├── js/                     # script.js
│   └── assets/ & img/          # Logotipos e imagens
├── server.js                   # Backend com Google Firebase Admin, Bcrypt e Sessões
├── serviceAccountKey.example.json # Modelo de credencial do Firebase
├── package.json                # Dependências instaladas (firebase-admin, bcryptjs, etc.)
├── .env / .env.example         # Configurações de ambiente
└── .gitignore                  # Protege suas chaves de API contra commits
```

---

## 🔥 Como Conectar ao seu Google Firebase (Passo a Passo)

Como assistente de IA, por políticas de segurança e privacidade da Google, não tenho permissão para acessar sua conta pessoal ou criar recursos na nuvem sem o seu login direto no navegador. Mas já deixei o código 100% pronto!

Para vincular o projeto ao seu Firebase (leva menos de 2 minutos e é gratuito):

1. **Acesse o Console do Firebase**:
   - Entre em [console.firebase.google.com](https://console.firebase.google.com/) com sua conta Google.
   - Clique em **"Adicionar projeto"** (ex: `agon-estudos`).

2. **Ative o Banco de Dados (Firestore)**:
   - No menu lateral esquerdo, clique em **Criação** ➔ **Firestore Database**.
   - Clique em **"Criar banco de dados"** e escolha o modo de produção ou teste (localização recomendada: `southamerica-east1` - São Paulo ou `us-central1`).

3. **Gerar a Chave de Acesso (Service Account)**:
   - Clique na engrenagem ⚙️ no canto superior esquerdo (ao lado de Visão geral do projeto) ➔ **Configurações do projeto**.
   - Vá na aba **Contas de serviço** (*Service accounts*).
   - Clique no botão **"Gerar nova chave privada"** (*Generate new private key*).
   - Um arquivo `.json` será baixado no seu computador.

4. **Coloque a chave no projeto**:
   - Renomeie o arquivo baixado para **`serviceAccountKey.json`**.
   - Mova-o para a raiz da pasta do projeto `Agon/`.
   - *(O arquivo `.gitignore` já está configurado para nunca expor essa chave no GitHub).*

5. **Pronto!** Ao iniciar o servidor, ele detectará a chave automaticamente e exibirá:
   `🔥 Google Firebase (Firestore) conectado com sucesso!`

---

## 🚀 Como Iniciar

1. Instale as dependências:
```bash
npm install
```

2. Inicie o servidor:
```bash
# Modo desenvolvimento (com recarregamento automático):
npm run dev

# Ou modo convencional:
npm start
```

3. Acesse no navegador:
- **Aplicação**: [http://localhost:3500](http://localhost:3500)
- **Login**: [http://localhost:3500/login](http://localhost:3500/login)
- **Cadastro**: [http://localhost:3500/cadastro](http://localhost:3500/cadastro)
