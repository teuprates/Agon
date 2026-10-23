require("dotenv").config();
const { randomUUID } = require("node:crypto");
const bcrypt = require("bcryptjs");
const { getSupabaseAdmin, isSupabaseConfigured } = require("../services/supabaseClient");

async function seedAdmin() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  const name = process.env.ADMIN_NAME?.trim() || "Administrador Agon";
  if (!isSupabaseConfigured()) throw new Error("Configure o Supabase server-side antes de criar o administrador.");
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("ADMIN_EMAIL precisa ser um e-mail válido.");
  if (!password || password.length < 20) throw new Error("ADMIN_PASSWORD precisa ter ao menos 20 caracteres.");

  const db = getSupabaseAdmin();
  const { data: admins, error: adminError } = await db.from("usuarios").select("id,email").eq("tipo_usuario", "administrador").limit(2);
  if (adminError) throw adminError;
  const existingAdmin = (admins || []).find((item) => item.email.toLowerCase() === email);
  if (admins?.length && !existingAdmin) throw new Error("Já existe um administrador. Um administrador atual deve promover novos usuários.");

  const { data: existingUser, error: userError } = await db.from("usuarios").select("id").ilike("email", email).maybeSingle();
  if (userError) throw userError;
  const values = { nome: name, email, senha: await bcrypt.hash(password, 12), tipo_usuario: "administrador" };
  const result = existingUser
    ? await db.from("usuarios").update(values).eq("id", existingUser.id).select("id").single()
    : await db.from("usuarios").insert({ id: randomUUID(), ...values, tipo_assinatura: "gratuito", pontos_gamificacao: 0 }).select("id").single();
  if (result.error) throw result.error;
  console.log("Administrador inicial configurado. As credenciais não foram exibidas.");
}

seedAdmin().catch((error) => {
  console.error("Não foi possível configurar o administrador:", error.message);
  process.exitCode = 1;
});
