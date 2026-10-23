/**
 * Cliente centralizado do Supabase.
 *
 * As chaves públicas podem ser usadas em clientes sujeitos a RLS.
 * Operações administrativas no servidor exigem SERVICE_ROLE/SECRET e nunca
 * devem aceitar uma chave pública como substituta.
 */
let createClient = null;
try {
  ({ createClient } = require("@supabase/supabase-js"));
} catch (err) {
  createClient = null;
}

let adminClientInstance = null;
let publicClientInstance = null;

function getSupabaseUrl() {
  return process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || "";
}

function getSecretKey() {
  return process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
}

function getPublicKey() {
  return process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    "";
}

function isValidUrl(url) {
  return typeof url === "string" &&
    url.trim().startsWith("https://") &&
    !url.includes("seu-projeto") &&
    !url.includes("sua-url");
}

function isValidKey(key) {
  return typeof key === "string" &&
    key.trim().length >= 20 &&
    !key.includes("sua_chave");
}

/** A aplicação usa o cliente administrativo nas operações persistentes do servidor. */
function isSupabaseConfigured() {
  return Boolean(
    createClient &&
    isValidUrl(getSupabaseUrl()) &&
    isValidKey(getSecretKey())
  );
}

/** Configuração suficiente para um cliente restrito por RLS. */
function isSupabasePublicConfigured() {
  return Boolean(
    createClient &&
    isValidUrl(getSupabaseUrl()) &&
    isValidKey(getPublicKey())
  );
}

function getSupabaseAdmin() {
  if (!isSupabaseConfigured()) return null;
  if (adminClientInstance) return adminClientInstance;

  adminClientInstance = createClient(getSupabaseUrl().trim(), getSecretKey().trim(), {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return adminClientInstance;
}

function getSupabaseClient() {
  if (!isSupabasePublicConfigured()) return null;
  if (publicClientInstance) return publicClientInstance;

  publicClientInstance = createClient(getSupabaseUrl().trim(), getPublicKey().trim(), {
    auth: { autoRefreshToken: true, persistSession: false },
  });
  return publicClientInstance;
}

function getSupabasePublicConfig() {
  if (!isSupabasePublicConfigured()) return null;
  return { url: getSupabaseUrl().trim(), publishableKey: getPublicKey().trim() };
}

function getSupabaseStatus() {
  const urlConfigured = isValidUrl(getSupabaseUrl());
  const publicKeyConfigured = isValidKey(getPublicKey());
  const serverKeyConfigured = isValidKey(getSecretKey());
  const configured = Boolean(createClient && urlConfigured && serverKeyConfigured);

  return {
    configurado: configured,
    urlConfigurada: urlConfigured,
    chavePublicaConfigurada: publicKeyConfigured,
    chaveServidorConfigurada: serverKeyConfigured,
    sdkDisponivel: Boolean(createClient),
    url: urlConfigured ? getSupabaseUrl().trim() : null,
    mensagem: configured
      ? "Supabase configurado para operações no servidor."
      : "Para operações do servidor, configure SUPABASE_URL (ou NEXT_PUBLIC_SUPABASE_URL) e SUPABASE_SERVICE_ROLE_KEY (ou SUPABASE_SECRET_KEY). A chave pública pode usar SUPABASE_ANON_KEY ou NEXT_PUBLIC_SUPABASE_ANON_KEY e não substitui a chave de servidor.",
  };
}

async function testSupabaseConnection() {
  if (!isSupabaseConfigured()) {
    return { ok: false, motivo: "URL ou chave secreta de servidor ausente/inválida" };
  }

  try {
    const admin = getSupabaseAdmin();
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
  isSupabasePublicConfigured,
  getSupabaseAdmin,
  getSupabaseClient,
  getSupabasePublicConfig,
  getSupabaseStatus,
  testSupabaseConnection,
};
