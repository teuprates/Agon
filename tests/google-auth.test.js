const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { createClient } = require("@supabase/supabase-js");

test("Google OAuth pede explicitamente que o usuário escolha uma conta", async () => {
  const helperUrl = pathToFileURL(path.join(__dirname, "../public/js/google-auth-options.mjs"));
  const { buildGoogleOAuthOptions } = await import(helperUrl.href);
  const options = buildGoogleOAuthOptions("https://agon-red.vercel.app");
  const supabase = createClient("https://example.supabase.co", "sb_publishable_test", {
    auth: { flowType: "pkce", persistSession: false },
  });
  const { data, error } = await supabase.auth.signInWithOAuth({
    ...options,
    options: { ...options.options, skipBrowserRedirect: true },
  });

  assert.ifError(error);
  const authorizationUrl = new URL(data.url);
  assert.equal(authorizationUrl.searchParams.get("prompt"), "select_account");
  assert.equal(authorizationUrl.searchParams.get("redirect_to"), "https://agon-red.vercel.app/auth/google/callback");
});

test("Botões Google de login e cadastro iniciam OAuth sem navegação legada", () => {
  for (const page of ["login.html", "cadastro.html"]) {
    const html = fs.readFileSync(path.join(__dirname, "../public", page), "utf8");
    const button = html.match(/<button\b(?=[^>]*data-google-auth)[^>]*>[\s\S]*?<\/button>/i)?.[0];

    assert.ok(button, `${page} must contain the Google auth button`);
    assert.doesNotMatch(button, /\bonclick\s*=/i, `${page} must not bypass OAuth`);
    assert.match(html, /src="\/js\/google-auth\.js"/);
  }
});
