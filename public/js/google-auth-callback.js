const message = document.getElementById("google-auth-message");

async function finishGoogleLogin() {
  try {
    const params = new URLSearchParams(window.location.search);
    const oauthError = params.get("error_description") || params.get("error");
    if (oauthError) throw new Error("O Google não concluiu a autenticação. Confira a configuração do provedor.");

    const code = params.get("code");
    if (!code) throw new Error("Código de autenticação não recebido do Google.");

    const configResponse = await fetch("/api/auth/google/config", { cache: "no-store" });
    const config = await configResponse.json();
    if (!configResponse.ok) throw new Error(config.erro || "Login Google indisponível.");

    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.118.0");
    const supabase = createClient(config.url, config.publishableKey, {
      auth: { flowType: "pkce", detectSessionInUrl: false, persistSession: true, autoRefreshToken: false },
    });
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);
    if (error || !data.session?.access_token) throw error || new Error("Sessão Google inválida.");

    window.history.replaceState({}, document.title, window.location.pathname);
    const response = await fetch("/api/auth/google/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ access_token: data.session.access_token }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.erro || "Não foi possível concluir o login.");
    window.location.replace("/dashboard");
  } catch (error) {
    message.textContent = error.message || "Não foi possível entrar com Google.";
    document.getElementById("google-auth-error").classList.remove("hidden");
  }
}

finishGoogleLogin();
