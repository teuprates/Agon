const { randomUUID } = require("node:crypto");
const { parse } = require("csv-parse/sync");

const MODALITIES = new Set(["multipla_escolha", "certo_errado"]);
const DIFFICULTIES = new Set(["facil", "media", "dificil"]);

function validateQuestion(input) {
  const errors = [];
  if (!input || typeof input !== "object" || Array.isArray(input)) return { errors: ["A questão precisa ser um objeto JSON."] };
  const text = (value, max, label, required = false) => {
    if (value == null && !required) return "";
    if (typeof value !== "string" || (required && !value.trim()) || value.length > max) {
      errors.push(`${label} deve ser texto${required ? " obrigatório" : ""} com até ${max} caracteres.`);
      return "";
    }
    return value.trim();
  };
  const disciplina = text(input.disciplina ?? input.disciplina_nome, 120, "Disciplina", true);
  const assunto = text(input.assunto ?? input.assunto_nome, 160, "Assunto", true);
  const banca = text(input.banca ?? input.banca_sigla, 60, "Banca", true);
  const enunciado = text(input.enunciado, 50000, "Enunciado", true);
  const textoAssociado = text(input.texto_associado ?? "", 30000, "Texto associado");
  const comentario = text(input.comentario_professor ?? input.comentario ?? "", 20000, "Comentário");
  const orgaoCargo = text(input.orgao_cargo ?? "", 200, "Órgão/cargo");
  const fonteUrl = text(input.fonte_url ?? "", 2048, "URL da fonte");
  const modalidade = input.modalidade || "multipla_escolha";
  const dificuldade = input.dificuldade || "media";
  const gabarito = typeof (input.gabarito ?? input.gabarito_oficial) === "string" ? (input.gabarito ?? input.gabarito_oficial).trim().toUpperCase() : "";
  if (!MODALITIES.has(modalidade)) errors.push("Modalidade inválida.");
  if (!DIFFICULTIES.has(dificuldade)) errors.push("Dificuldade inválida.");
  if (!/^(19|20)\d{2}$/.test(String(input.ano ?? ""))) errors.push("Ano inválido.");
  if (modalidade === "certo_errado" ? !["C", "E"].includes(gabarito) : !["A", "B", "C", "D", "E"].includes(gabarito)) errors.push("Gabarito inválido para a modalidade.");
  if (!Array.isArray(input.alternativas) || input.alternativas.length < 2 || input.alternativas.length > 5) {
    errors.push("Informe de 2 a 5 alternativas.");
  }
  const seen = new Set();
  const alternatives = (Array.isArray(input.alternativas) ? input.alternativas : []).map((alternative, index) => {
    const letra = typeof alternative?.letra === "string" ? alternative.letra.trim().toUpperCase() : "";
    const texto = text(alternative?.texto, 10000, `Alternativa ${index + 1}`, true);
    const justificativa = text(alternative?.justificativa_alternativa ?? alternative?.justificativa ?? "", 5000, `Justificativa ${index + 1}`);
    if (!/^[A-E]$/.test(letra) || seen.has(letra)) errors.push(`Letra inválida ou repetida na alternativa ${index + 1}.`);
    seen.add(letra);
    return { letra, texto, justificativa_alternativa: justificativa, ordem: index + 1, correta: letra === gabarito };
  });
  if (modalidade === "certo_errado" && (!seen.has("C") || !seen.has("E") || alternatives.length !== 2)) errors.push("Questões C/E precisam ter somente as alternativas C e E.");
  if (modalidade === "multipla_escolha" && !alternatives.some((alternative) => alternative.letra === gabarito)) errors.push("O gabarito não corresponde a uma alternativa.");
  const ano = Number(input.ano);
  const codigo = input.codigo == null ? "" : text(input.codigo, 40, "Código");
  return {
    errors,
    question: {
      id: randomUUID(),
      codigo,
      disciplina_slug: text(input.disciplina_slug || disciplina.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "-"), 80, "Identificador da disciplina", true),
      disciplina_nome: disciplina,
      assunto_nome: assunto,
      banca_sigla: banca,
      ano,
      orgao_cargo: orgaoCargo || null,
      modalidade,
      dificuldade,
      texto_associado: textoAssociado || null,
      enunciado,
      gabarito_oficial: gabarito,
      comentario_professor: comentario || null,
      fonte_url: fonteUrl || null,
      alternativas: alternatives,
    },
  };
}

function parseQuestionDocument(document) {
  if (Array.isArray(document)) return document;
  if (document && Array.isArray(document.questoes)) return document.questoes;
  throw new Error("O JSON precisa ser uma lista ou conter a propriedade questoes.");
}

function parseQuestionCsv(csvText) {
  if (typeof csvText !== "string" || csvText.length > 1024 * 1024) throw new Error("O CSV precisa ser texto com até 1 MB.");
  const rows = parse(csvText, { columns: true, bom: true, skip_empty_lines: true, trim: true });
  return rows.map((row, index) => {
    try { return { ...row, alternativas: JSON.parse(row.alternativas || "[]") }; }
    catch (error) { throw new Error(`A coluna alternativas da linha ${index + 2} precisa conter um JSON válido.`, { cause: error }); }
  });
}

module.exports = { validateQuestion, parseQuestionDocument, parseQuestionCsv };
