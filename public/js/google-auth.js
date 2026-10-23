import { buildGoogleOAuthOptions } from "./google-auth-options.mjs";

const googleButton = document.querySelector("[data-google-auth]");

if (googleButton) {
  googleButton.addEventListener("click", async () => {
    googleButton.disabled = true;
    const label = googleButton.querySelector("span");
    const originalLabel = label?.textContent || "Google";
    if (label) label.textContent = "Conectando ao Google...";

    try {
      const configResponse = await fetch("/api/auth/google/config", { cache: "no-store" });
      const config = await configResponse.json();
      if (!configResponse.ok) throw new Error(config.erro || "Login Google indisponível.");

      const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.118.0");
      const supabase = createClient(config.url, config.publishableKey, {
        auth: { flowType: "pkce", detectSessionInUrl: true, persistSession: true, autoRefreshToken: false },
      });
      const { error } = await supabase.auth.signInWithOAuth(
        buildGoogleOAuthOptions(window.location.origin)
      );
      if (error) throw error;
    } catch (error) {
      const alertBox = document.getElementById("login-alert") || document.getElementById("cadastro-alert");
      if (alertBox) {
        alertBox.className = "p-3.5 rounded-xl text-xs font-medium bg-red-100 text-red-700 border border-red-200";
        alertBox.textContent = error.message || "Não foi possível iniciar o login Google.";
        alertBox.classList.remove("hidden");
      }
      googleButton.disabled = false;
      if (label) label.textContent = originalLabel;
    }
  });
}
