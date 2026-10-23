const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const readPage = (directory, filename) =>
  fs.readFileSync(path.join(__dirname, "..", directory, filename), "utf8");

test("Paginas sem persistencia identificam visivelmente os dados demonstrativos", () => {
  for (const page of ["aulas", "materiais", "estudos", "simulados", "comunidade", "conquistas", "configuracoes", "em-breve"]) {
    const html = readPage("protected-pages", `${page}.html`);
    assert.match(html, /Protótipo — dados de demonstração\./, `${page} must disclose its prototype status`);
  }

  assert.match(readPage("protected-pages", "index.html"), /Dashboard parcialmente integrado/);
  assert.match(readPage("protected-pages", "planos-estudo.html"), /Integração parcial/);
  const questions = readPage("protected-pages", "questoes.html");
  assert.match(questions, /id="question-list"/);
  assert.doesNotMatch(questions, /data-correct=|gabarito_oficial|Mostrando 3 de 3/);
});

test("Landing page não apresenta métricas ou depoimentos inventados como reais", () => {
  const home = readPage("public", "home.html");
  const signup = readPage("public", "cadastro.html");
  const visibleText = (html) => html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<svg\b[^>]*>[\s\S]*?<\/svg>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ");

  for (const claim of ["50.000", "92,4%", "4.9 ★", "Top 5%", "+250 XP", "12.000"]) {
    assert.ok(!visibleText(home).includes(claim) && !visibleText(signup).includes(claim), `Unexpected unsupported claim: ${claim}`);
  }
  assert.match(home, /Não é depoimento de usuário/);
  assert.match(home, /Prévia demonstrativa/);
});
