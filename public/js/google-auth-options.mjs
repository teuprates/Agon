export function buildGoogleOAuthOptions(origin) {
  return {
    provider: "google",
    options: {
      redirectTo: `${origin}/auth/google/callback`,
      queryParams: { prompt: "select_account" },
    },
  };
}
