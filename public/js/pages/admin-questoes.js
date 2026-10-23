document.addEventListener("DOMContentLoaded", () => {
  const $ = (selector) => document.querySelector(selector);
  const form = $("#question-form"), alternatives = $("#alternatives"), answerKey = form.elements.gabarito;
  const lettersFor = () => form.elements.modalidade.value === "certo_errado" ? ["C", "E"] : ["A", "B", "C", "D", "E"];

  function renderAlternatives() {
    const letters = lettersFor();
    alternatives.replaceChildren();
    answerKey.replaceChildren(...letters.map((letter) => new Option(letter, letter)));
    for (const letter of letters) {
      const label = document.createElement("label");
      label.className = "text-sm";
      label.append(document.createTextNode("Alternativa " + letter));
      const textarea = document.createElement("textarea");
      textarea.className = "field mt-1";
      textarea.rows = 3;
      textarea.maxLength = 10000;
      textarea.dataset.letra = letter;
      textarea.required = true;
      label.append(textarea);
      alternatives.append(label);
    }
  }

  async function loadQuestions() {
    const container = $("#question-table");
    container.textContent = "Carregando…";
    try {
      const response = await fetch("/api/admin/questoes"), data = await response.json();
      if (!response.ok) throw new Error(data.erro || "Não foi possível carregar as questões.");
      container.replaceChildren();
      if (!data.questoes.length) { container.textContent = "Nenhuma questão cadastrada."; return; }
      for (const q of data.questoes) {
        const row = document.createElement("article");
        row.className = "rounded-xl border border-slate-200 p-3";
        const title = document.createElement("p");
        title.className = "font-semibold";
        title.textContent = q.codigo + " · " + q.disciplina_nome + " · " + q.assunto_nome;
        const details = document.createElement("p");
        details.className = "mt-1 text-slate-600";
        details.textContent = (q.ativa ? "Ativa" : q.anulada ? "Anulada" : "Inativa") + " · origem: " + q.origem;
        row.append(title, details);
        const actions = document.createElement("div"); actions.className = "mt-2 flex gap-2";
        for (const [label, status] of [[q.ativa ? "Desativar" : "Ativar", q.ativa ? "inativa" : "ativa"], ["Marcar anulada", "anulada"]]) {
          const button = document.createElement("button"); button.type = "button"; button.className = "btn-secondary rounded px-3 py-1"; button.textContent = label;
          button.addEventListener("click", async () => {
            button.disabled = true;
            try { const response = await fetch("/api/admin/questoes/" + q.id + "/status", { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ status }) }); const result = await response.json(); if (!response.ok) throw new Error(result.erro); await loadQuestions(); }
            catch (error) { $("#form-status").textContent = error.message; button.disabled = false; }
          });
          actions.append(button);
        }
        row.append(actions); container.append(row);
      }
    } catch (error) { container.textContent = error.message; }
  }

  form.elements.modalidade.addEventListener("change", renderAlternatives);
  renderAlternatives();
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const formData = new FormData(form);
    const question = Object.fromEntries(formData.entries());
    question.alternativas = [...alternatives.querySelectorAll("textarea")].map((field) => ({ letra: field.dataset.letra, texto: field.value }));
    $("#form-status").textContent = "Salvando…";
    try {
      const response = await fetch("/api/admin/questoes", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(question) });
      const result = await response.json();
      if (!response.ok) throw new Error([result.erro, ...(result.erros || [])].filter(Boolean).join(" "));
      $("#form-status").textContent = "Questão " + result.codigo + " salva e publicada.";
      form.reset(); renderAlternatives(); await loadQuestions();
    } catch (error) { $("#form-status").textContent = error.message; }
  });

  $("#import-json").addEventListener("click", async () => {
    const file = $("#json-file").files[0];
    if (!file) { $("#import-status").textContent = "Selecione um arquivo JSON ou CSV."; return; }
    try {
      if (file.size > 1024 * 1024) throw new Error("O arquivo precisa ter até 1 MB.");
      const text = await file.text();
      const csv = file.name.toLowerCase().endsWith(".csv");
      const document = csv ? text : JSON.stringify(JSON.parse(text));
      const response = await fetch("/api/admin/questoes/importar-" + (csv ? "csv" : "json"), { method: "POST", headers: { "Content-Type": csv ? "text/csv" : "application/json" }, body: document });
      const result = await response.json(); if (!response.ok && response.status !== 207) throw new Error(result.erro || "Falha na importação.");
      $("#import-status").textContent = "Importadas: " + result.importadas.length + " · duplicadas: " + result.duplicadas.length + " · erros: " + result.erros.length + "\n" + JSON.stringify(result.erros, null, 2);
      await loadQuestions();
    } catch (error) { $("#import-status").textContent = error.message; }
  });
  loadQuestions();
});
