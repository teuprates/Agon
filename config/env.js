function validateEnv(env = process.env) {
  if (env.NODE_ENV !== "production") return;

  if (typeof env.SESSION_SECRET !== "string" || env.SESSION_SECRET.length < 32) {
    throw new Error("SESSION_SECRET precisa ter pelo menos 32 caracteres em produção.");
  }

  const supabaseUrl = env.SUPABASE_URL || env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseSecret = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !supabaseSecret) {
    throw new Error("Supabase precisa estar configurado em produção para persistência e sessões.");
  }
}

module.exports = { validateEnv };
