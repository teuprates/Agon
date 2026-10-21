const express = require("express");
const bodyParser = require("body-parser");
const path = require("path");
const fs = require("fs");
const bcrypt = require("bcryptjs");
const session = require("express-session");
const admin = require("firebase-admin");
require("dotenv").config();

const app = express();

// ==========================================
// CONFIGURAÇÃO DO GOOGLE FIREBASE
// ==========================================
let db = null;
let isFirebaseConnected = false;

// Fallback em memória (para testes antes de adicionar o serviceAccountKey.json)
const localUsersStore = new Map();

const serviceAccountPath = path.join(__dirname, "serviceAccountKey.json");

if (fs.existsSync(serviceAccountPath)) {
  try {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    db = admin.firestore();
    isFirebaseConnected = true;
    console.log("🔥 Google Firebase (Firestore) conectado com sucesso!");
  } catch (err) {
    console.error("❌ Erro ao inicializar o Firebase:", err.message);
  }
} else {
  console.log("==================================================================");
  console.log("ℹ️  AVISO DO GOOGLE FIREBASE:");
  console.log("O arquivo 'serviceAccountKey.json' ainda não foi colocado na raiz.");
  console.log("O servidor iniciou com armazenamento local para você testar agora.");
  console.log("Para conectar à sua conta Google Firebase:");
  console.log("  1. Acesse: https://console.firebase.google.com");
  console.log("  2. Crie seu projeto e ative o 'Firestore Database'.");
  console.log("  3. Em 'Configurações do Projeto' > 'Contas de Serviço', clique em");
  console.log("     'Gerar nova chave privada'.");
  console.log("  4. Salve o arquivo baixado como 'serviceAccountKey.json' na pasta Agon.");
  console.log("==================================================================");
}

// Middlewares
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
// { index: false } impede que o static intercepte a raiz com index.html
app.use(express.static(path.join(__dirname, "public"), { index: false }));

// Configuração da sessão
app.use(
  session({
    secret: process.env.SESSION_SECRET || "agon-secret-key-firebase-2026",
    resave: false,
    saveUninitialized: false,
    cookie: {
      secure: false,
      maxAge: 24 * 60 * 60 * 1000, // 24 horas
    },
  })
);

// Middleware para verificar autenticação
const requireAuth = (req, res, next) => {
  if (req.session.user) {
    next();
  } else {
    res.redirect("/login");
  }
};

// Rotas para páginas principais
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/home", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/landing", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "home.html"));
});

app.get("/dashboard", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.get("/login", (req, res) => {
  if (req.session.user) {
    return res.redirect("/dashboard");
  }
  res.sendFile(path.join(__dirname, "public", "login.html"));
});

app.get("/cadastro", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "cadastro.html"));
});

app.get("/servicos", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "materiais.html"));
});

app.get("/sobre", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "comunidade.html"));
});

// Rota protegida - só acessa se estiver logado
app.get("/setores", requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, "public", "estudos.html"));
});

// Rotas para todas as páginas da plataforma Agon
const agonPages = [
  "index",
  "home",
  "aulas",
  "planos-estudo",
  "materiais",
  "estudos",
  "questoes",
  "simulados",
  "desempenho",
  "ia-tutor",
  "comunidade",
  "conquistas",
  "configuracoes",
  "em-breve",
];

agonPages.forEach((page) => {
  app.get(`/${page}`, (req, res) => {
    res.sendFile(path.join(__dirname, "public", `${page}.html`));
  });
});

// ==========================================
// APIS DE AUTENTICAÇÃO COM FIREBASE
// ==========================================

// API - Cadastro
app.post("/api/cadastrar", async (req, res) => {
  const {
    nome,
    email,
    senha,
    telefone,
    tipo_usuario = "aluno",
    tipo_assinatura = "gratuito",
  } = req.body;

  if (!nome || !email || !senha || !telefone) {
    console.log(`[CADASTRO FALHOU]: Campos obrigatórios faltando. Email: ${email || "N/A"}`);
    return res.status(400).json({ erro: "Todos os campos são obrigatórios." });
  }

  if (senha.length < 6) {
    console.log(`[CADASTRO FALHOU]: Senha muito curta. Email: ${email}`);
    return res.status(400).json({ erro: "A senha deve ter pelo menos 6 caracteres." });
  }

  try {
    const saltRounds = 10;
    const hash = await bcrypt.hash(senha, saltRounds);

    if (isFirebaseConnected && db) {
      // 1. Verificar se usuário já existe no Firestore
      const userQuery = await db.collection("usuarios").where("email", "==", email.toLowerCase().trim()).get();
      if (!userQuery.empty) {
        console.log(`[CADASTRO FALHOU]: E-mail já cadastrado. Email: ${email}`);
        return res.status(400).json({ erro: "Este e-mail já está cadastrado." });
      }

      // 2. Inserir no Firestore
      const novoUsuario = {
        nome,
        email: email.toLowerCase().trim(),
        senha: hash,
        telefone,
        tipo_usuario,
        tipo_assinatura,
        pontos_gamificacao: 0,
        criado_em: admin.firestore.FieldValue.serverTimestamp(),
      };

      const docRef = await db.collection("usuarios").add(novoUsuario);

      console.log(`[CADASTRO SUCESSO - FIREBASE]: Usuário cadastrado com ID: ${docRef.id} (${email})`);
      return res.status(201).json({
        sucesso: "Usuário cadastrado com sucesso no Firebase!",
        usuarioId: docRef.id,
      });
    } else {
      // Armazenamento em memória fallback (enquanto não coloca serviceAccountKey.json)
      const existing = Array.from(localUsersStore.values()).find(
        (u) => u.email === email.toLowerCase().trim()
      );
      if (existing) {
        return res.status(400).json({ erro: "Este e-mail já está cadastrado." });
      }

      const id = "local_" + Date.now();
      const novoUsuario = {
        id,
        nome,
        email: email.toLowerCase().trim(),
        senha: hash,
        telefone,
        tipo_usuario,
        tipo_assinatura,
        pontos_gamificacao: 0,
        criado_em: new Date().toISOString(),
      };

      localUsersStore.set(id, novoUsuario);
      console.log(`[CADASTRO SUCESSO - LOCAL]: Usuário cadastrado ID: ${id} (${email})`);
      return res.status(201).json({
        sucesso: "Usuário cadastrado com sucesso (modo local)! Configure o Firebase para persistência na nuvem.",
        usuarioId: id,
      });
    }
  } catch (error) {
    console.error("[ERRO CADASTRO]:", error);
    return res.status(500).json({ erro: "Erro interno no servidor ao registrar usuário." });
  }
});

// API - Login
app.post("/api/login", async (req, res) => {
  const { email, senha } = req.body;

  if (!email || !senha) {
    console.log("[LOGIN FALHOU]: E-mail ou senha não fornecidos.");
    return res.status(400).json({ erro: "E-mail e senha são obrigatórios." });
  }

  try {
    let user = null;
    let userId = null;

    if (isFirebaseConnected && db) {
      const userSnapshot = await db
        .collection("usuarios")
        .where("email", "==", email.toLowerCase().trim())
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        console.log(`[LOGIN FALHOU]: E-mail não encontrado no Firebase. Email: ${email}`);
        return res.status(401).json({ erro: "E-mail ou senha inválidos." });
      }

      const doc = userSnapshot.docs[0];
      user = doc.data();
      userId = doc.id;
    } else {
      // Busca no fallback local
      const found = Array.from(localUsersStore.entries()).find(
        ([, u]) => u.email === email.toLowerCase().trim()
      );
      if (!found) {
        console.log(`[LOGIN FALHOU]: E-mail não encontrado (local). Email: ${email}`);
        return res.status(401).json({ erro: "E-mail ou senha inválidos." });
      }
      userId = found[0];
      user = found[1];
    }

    const isMatch = await bcrypt.compare(senha, user.senha);
    if (!isMatch) {
      console.log(`[LOGIN FALHOU]: Senha inválida para: ${email}`);
      return res.status(401).json({ erro: "E-mail ou senha inválidos." });
    }

    // Cria a sessão com os dados do usuário
    req.session.user = {
      id: userId,
      nome: user.nome,
      email: user.email,
      telefone: user.telefone,
      tipo_usuario: user.tipo_usuario,
      tipo_assinatura: user.tipo_assinatura,
      pontos_gamificacao: user.pontos_gamificacao || 0,
    };

    console.log(`[LOGIN SUCESSO]: Usuário logado - ID: ${userId}, Nome: ${user.nome}`);

    res.status(200).json({
      sucesso: "Login efetuado com sucesso!",
      usuario: req.session.user,
    });
  } catch (error) {
    console.error("[ERRO LOGIN]:", error);
    res.status(500).json({ erro: "Erro interno no servidor ao realizar login." });
  }
});

// API - Logout
app.post("/api/logout", (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      console.error("[ERRO SESSÃO]: Erro ao fazer logout:", err);
      return res.status(500).json({ erro: "Erro ao fazer logout." });
    }
    res.clearCookie("connect.sid");
    res.status(200).json({ sucesso: "Logout realizado com sucesso!" });
  });
});

// API - Buscar dados completos do usuário
app.get("/api/user/:id", requireAuth, async (req, res) => {
  const userId = req.params.id;

  if (userId !== req.session.user.id) {
    console.log(`[ACESSO NEGADO]: Usuário ${req.session.user.id} tentou acessar dados de ${userId}`);
    return res.status(403).json({ erro: "Acesso não autorizado." });
  }

  try {
    if (isFirebaseConnected && db) {
      const doc = await db.collection("usuarios").doc(userId).get();
      if (!doc.exists) {
        return res.status(404).json({ erro: "Usuário não encontrado." });
      }
      const data = doc.data();
      delete data.senha; // Nunca expor o hash da senha
      return res.status(200).json({ id: doc.id, ...data });
    } else {
      const user = localUsersStore.get(userId);
      if (!user) {
        return res.status(404).json({ erro: "Usuário não encontrado." });
      }
      const data = { ...user };
      delete data.senha;
      return res.status(200).json(data);
    }
  } catch (err) {
    console.error("[ERRO BUSCAR USUÁRIO]:", err);
    res.status(500).json({ erro: "Erro interno ao buscar usuário." });
  }
});

// API - Verificar autenticação
app.get("/api/check-auth", async (req, res) => {
  if (req.session.user) {
    try {
      if (isFirebaseConnected && db) {
        const doc = await db.collection("usuarios").doc(req.session.user.id).get();
        if (doc.exists) {
          const userData = doc.data();
          req.session.user = {
            id: doc.id,
            nome: userData.nome,
            email: userData.email,
            telefone: userData.telefone,
            tipo_usuario: userData.tipo_usuario,
            tipo_assinatura: userData.tipo_assinatura,
            pontos_gamificacao: userData.pontos_gamificacao || 0,
          };
        }
      }
    } catch (err) {
      console.warn("Aviso ao atualizar sessão do Firebase:", err.message);
    }
    return res.status(200).json({ autenticado: true, usuario: req.session.user });
  }
  res.status(200).json({ autenticado: false });
});

// Inicialização do servidor
const PORT = process.env.PORT || 3500;
app.listen(PORT, () => {
  console.log(`=========================================`);
  console.log(`🚀 Servidor Agon rodando em http://localhost:${PORT}`);
  console.log(`🌐 Firebase Status: ${isFirebaseConnected ? "Conectado 🔥" : "Modo Local (Aguardando Chave) ⚡"}`);
  console.log(`=========================================`);
});
