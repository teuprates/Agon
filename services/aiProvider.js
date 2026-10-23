/**
 * Camada de Abstração para Provedores de Inteligência Artificial
 * Permite alternar entre provedores (Google Gemini, OpenAI, etc.) sem refatorar o restante do sistema.
 */

class AIProvider {
  /**
   * Envia uma lista de mensagens e instruções de sistema para o modelo.
   * @param {Object} params
   * @param {string} params.systemInstruction Instrução base do sistema
   * @param {Array<{role: string, content: string}>} params.messages Histórico de mensagens
   * @param {number} [params.timeoutMs=25000] Timeout da requisição
   * @returns {Promise<{text: string, provider: string, model: string}>}
   */
  async generateResponse({ systemInstruction, messages, timeoutMs = 25000 }) {
    throw new Error("Método generateResponse deve ser implementado pelo provedor");
  }

  isConfigured() {
    throw new Error("Método isConfigured deve ser implementado pelo provedor");
  }

  getProviderName() {
    return "base";
  }
}

/**
 * Provedor Oficial Google Gemini
 * Utiliza o endpoint da API REST v1beta com suporte a systemInstruction e geração de conteúdo.
 */
class GeminiProvider extends AIProvider {
  constructor(apiKey, primaryModel = "gemini-flash-lite-latest") {
    super();
    this.apiKey = typeof apiKey === "string" ? apiKey : (process.env.GEMINI_API_KEY || "");
    this.primaryModel = process.env.GEMINI_MODEL || primaryModel;
    this.fallbackModel = "gemini-flash-lite-latest";
  }

  isConfigured() {
    return Boolean(this.apiKey && this.apiKey.trim().length > 10 && !this.apiKey.includes("sua_chave"));
  }

  getProviderName() {
    return "Google Gemini";
  }

  getActiveModel() {
    return this.primaryModel;
  }

  /**
   * Converte mensagens para o formato da API Gemini (roles: 'user' e 'model')
   */
  formatContents(messages) {
    return messages.map((m) => {
      const role = m.role === "assistant" || m.role === "model" ? "model" : "user";
      return {
        role,
        parts: [{ text: String(m.content || "") }],
      };
    });
  }

  /**
   * Executa a chamada HTTP com timeout inteligente e alternância automática ultra-rápida entre modelos
   */
  async generateResponse({ systemInstruction, messages, timeoutMs = 35000 }) {
    if (!this.isConfigured()) {
      const err = new Error(
        "A chave de API da Zuka IA (GEMINI_API_KEY) não está configurada no arquivo .env do servidor."
      );
      err.code = "KEY_MISSING";
      err.status = 503;
      throw err;
    }

    // Modelos resilientes ordenados por velocidade e disponibilidade comprovada
    const candidateModels = Array.from(new Set([
      this.primaryModel,
      "gemini-flash-lite-latest",
      "gemini-3.5-flash-lite",
      "gemini-3.1-flash-lite",
      "gemini-3.5-flash",
      "gemini-3.7-flash"
    ])).filter(Boolean);

    // Timeout por modelo individual (máximo de 11 segundos cada para não travar a experiência do usuário)
    const perAttemptTimeoutMs = 11000;
    const overallDeadline = Date.now() + timeoutMs;

    let lastError = null;
    for (const model of candidateModels) {
      const timeLeft = overallDeadline - Date.now();
      if (timeLeft <= 2000) {
        break;
      }
      const attemptTimeout = Math.min(perAttemptTimeoutMs, timeLeft);

      try {
        const response = await this._callGeminiEndpoint(model, systemInstruction, messages, attemptTimeout);
        return response;
      } catch (err) {
        lastError = err;

        // Erro fatal de autenticação (não adianta tentar outro modelo se a chave for inválida)
        if (err.code === "INVALID_KEY") {
          throw err;
        }

        const shouldFailover =
          err.status === 404 ||
          err.status === 503 ||
          err.status === 504 ||
          err.status === 429 ||
          err.code === "TIMEOUT" ||
          err.name === "AbortError";

        if (shouldFailover) {
          console.warn(`[GEMINI PROVIDER] Modelo '${model}' demorou ou retornou ${err.status || err.code}. Acionando modelo alternativo mais rápido...`);
          continue;
        }

        throw err;
      }
    }

    if (lastError) {
      if (lastError.code === "TIMEOUT" || lastError.name === "AbortError") {
        const timeoutErr = new Error(
          "Os servidores do Google Gemini demoraram mais do que o esperado. Tentamos modelos alternativos sem sucesso momentaneamente. Por favor, tente novamente em alguns segundos."
        );
        timeoutErr.code = "TIMEOUT";
        timeoutErr.status = 504;
        throw timeoutErr;
      }
      throw lastError;
    }
  }

  async _callGeminiEndpoint(modelName, systemInstruction, messages, timeoutMs) {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(modelName)}:generateContent?key=${encodeURIComponent(this.apiKey)}`;

    const formattedContents = this.formatContents(messages);
    if (formattedContents.length === 0) {
      const err = new Error("A mensagem para o Gemini está vazia. Envie uma pergunta e tente novamente.");
      err.code = "EMPTY_CONTENTS";
      err.status = 400;
      throw err;
    }

    const payload = {
      contents: formattedContents,
      generationConfig: {
        temperature: 0.35, // Didático e conciso para concursos públicos
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1536,
      },
    };

    if (systemInstruction) {
      payload.systemInstruction = {
        parts: [{ text: systemInstruction }],
      };
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        let parsedError = {};
        try {
          parsedError = JSON.parse(errorText);
        } catch (_) {}

        const errorMessage = parsedError.error?.message || errorText;
        const statusCode = response.status;

        // Trata limite de requisições (Quota/Rate Limit)
        if (statusCode === 429 || errorMessage.toLowerCase().includes("quota") || errorMessage.toLowerCase().includes("resource_exhausted")) {
          const quotaErr = new Error(
            "O limite de requisições gratuitas da Zuka IA (Google Gemini) foi atingido temporariamente. Por favor, aguarde alguns instantes e tente novamente."
          );
          quotaErr.code = "RATE_LIMIT_EXCEEDED";
          quotaErr.status = 429;
          throw quotaErr;
        }

        // Chave inválida ou não autorizada
        if (statusCode === 400 || statusCode === 403) {
          if (errorMessage.toLowerCase().includes("api_key") || errorMessage.toLowerCase().includes("invalid")) {
            const authErr = new Error(
              "A chave da API GEMINI_API_KEY configurada é inválida ou expirou. Verifique as credenciais no Google AI Studio."
            );
            authErr.code = "INVALID_KEY";
            authErr.status = 403;
            throw authErr;
          }
        }

        const genericErr = new Error(`Erro na API Google Gemini (${statusCode}): ${errorMessage}`);
        genericErr.code = "API_ERROR";
        genericErr.status = statusCode;
        throw genericErr;
      }

      const data = await response.json();
      const candidate = data.candidates?.[0];

      if (!candidate || !candidate.content?.parts?.length) {
        // Possível bloqueio de segurança do modelo
        if (candidate?.finishReason === "SAFETY") {
          const safetyErr = new Error("A resposta foi bloqueada pelos filtros de segurança de conteúdo do modelo.");
          safetyErr.code = "SAFETY_BLOCK";
          safetyErr.status = 422;
          throw safetyErr;
        }
        throw new Error("A IA não retornou conteúdo textual para esta solicitação.");
      }

      const text = candidate.content.parts.map((p) => p.text).join("");

      return {
        text,
        provider: "Google Gemini",
        model: modelName,
        finishReason: candidate.finishReason,
      };
    } catch (err) {
      clearTimeout(timeoutId);

      if (err.name === "AbortError") {
        const timeoutErr = new Error(
          `A Zuka IA demorou mais de ${Math.round(timeoutMs / 1000)}s para responder e a solicitação expirou. Tente uma pergunta mais direta.`
        );
        timeoutErr.code = "TIMEOUT";
        timeoutErr.status = 504;
        throw timeoutErr;
      }

      throw err;
    }
  }
}

// Fábrica de instâncias de IA
let currentProvider = null;

function getAIProvider() {
  if (!currentProvider || currentProvider.apiKey !== process.env.GEMINI_API_KEY || currentProvider.primaryModel !== process.env.GEMINI_MODEL) {
    currentProvider = new GeminiProvider(process.env.GEMINI_API_KEY, process.env.GEMINI_MODEL || "gemini-3.8-flash");
  }
  return currentProvider;
}

module.exports = {
  AIProvider,
  GeminiProvider,
  getAIProvider,
};
