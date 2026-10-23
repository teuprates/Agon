const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const path = require("node:path");

const repoRoot = path.join(__dirname, "..");
const inspectTrustProxy = (environment) => spawnSync(
  process.execPath,
  ["-e", 'const app = require("./server"); process.stdout.write(String(app.get("trust proxy")));'],
  {
    cwd: repoRoot,
    encoding: "utf8",
    env: {
      PATH: process.env.PATH,
      NODE_ENV: environment,
      SESSION_SECRET: "test-only-session-secret-that-is-long-enough-123456",
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_SECRET_KEY: "test-only-supabase-secret-key-1234567890",
    },
  },
);

test("Express confia no proxy apenas em produção", () => {
  const production = inspectTrustProxy("production");
  assert.equal(production.status, 0, production.stderr);
  assert.equal(production.stdout.trim().split(/\r?\n/).at(-1), "1");

  const nonProduction = inspectTrustProxy("test");
  assert.equal(nonProduction.status, 0, nonProduction.stderr);
  assert.equal(nonProduction.stdout.trim().split(/\r?\n/).at(-1), "false");
});
