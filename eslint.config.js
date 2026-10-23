const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
  { ignores: ["node_modules/**", "public/css/tailwind.css", "data/**", "supabase/.temp/**"] },
  {
    files: ["**/*.js"],
    ...js.configs.recommended,
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "commonjs",
      globals: { ...globals.node, ...globals.browser, ...globals.es2021 },
    },
    rules: {
      ...js.configs.recommended.rules,
      "no-unused-vars": "off",
      "no-undef": "error",
    },
  },
  {
    files: ["public/js/**/*.js"],
    languageOptions: { sourceType: "module" },
  },
];
