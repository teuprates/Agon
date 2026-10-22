/**
 * Cliente Centralizado Supabase para o Projeto AGON
 * Gerencia a inicialização, credenciais e instâncias do SDK @supabase/supabase-js
 */

const { createClient } = require("@supabase/supabase-js");

let adminClientInstance = null;
let publicClientInstance = null;

/**
 * Valida se as variáveis de ambiente necessárias para o Supabase estão configuradas
 */
function isSupabaseConfigured() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

  if (!url || typeof url !== "string" || !url.trim().startsWith("https://")) {
    return false;
  }

  if (url.includes("seu-projeto") || url.includes("sua-url")) {
    return false;
  }

  if (!key || typeof key !== "string" || key.trim().length < 20 || key.includes("sua_chave")) {
    return false;
  }

  return true;
}

/**
 * Retorna o cliente administrativo (Service Role) para operações no servidor
 * Nunca deve ser exposto ao navegador
 */
function getSupabaseAdmin() {
  if (!isSupabaseConfigured()) {
    return null;
  }

  if (adminClientInstance) {
    return adminClientInstance;
  }

  const supabaseUrl = process.env.SUPABASE_URL.trim();
  const serviceRoleKey = (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY).trim();

  adminClientInstance = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  return adminClientInstance;
}

/**
 * Retorna o cliente público/anônimo do Supabase (com permissões restritas a RLS)
 */
function getSupabaseClient() {
  if (!isSupabaseConfigured()) {
    return null;
  }

  if (publicClientInstance) {
    return publicClientInstance;
  }

  const supabaseUrl = process.env.SUPABASE_URL.trim();
  const anonKey = (process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY).trim();

  publicClientInstance = createClient(supabaseUrl, anonKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: false,
    },
  });

  return publicClientInstance;
}

/**
 * Retorna o status detalhado da conexão com o Supabase
 */
function getSupabaseStatus() {
  const configured = isSupabaseConfigured();
  return {
    configurado: configured,
    url: configured ? process.env.SUPABASE_URL.trim() : null,
    mensagem: configured
      ? "Supabase configurado e pronto para operações na nuvem."
      : "Credenciais do Supabase não configuradas no arquivo .env (SUPABASE_URL e SUPABASE_ANON_KEY/SUPABASE_SERVICE_ROLE_KEY). O sistema está operando com banco local persistente.",
  };
}

/**
 * Testa a conexão real com o Supabase executando uma consulta leve
 */
async function testSupabaseConnection() {
  if (!isSupabaseConfigured()) {
    return { ok: false, motivo: "Credenciais ausentes no .env" };
  }

  try {
    const admin = getSupabaseAdmin();
    // Tenta uma consulta de contagem na tabela de perfis/usuarios
    const { error } = await admin.from("usuarios").select("id", { count: "exact", head: true });
    if (error && error.code !== "PGRST116") {
      return { ok: false, erro: error.message, code: error.code };
    }
    return { ok: true };
  } catch (err) {
    return { ok: false, erro: err.message };
  }
}

module.exports = {
  isSupabaseConfigured,
  getSupabaseAdmin,
  getSupabaseClient,
  getSupabaseStatus,
  testSupabaseConnection,
};
