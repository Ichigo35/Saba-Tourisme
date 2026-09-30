/**
 * Proxy Cloudflare Worker pour le mode "Conversation IA" de Sabai Tourisme.
 *
 * Pourquoi ce Worker existe : la clé API Gemini ne doit jamais être
 * embarquée dans l'app Android (un APK se décompile facilement, la clé
 * serait extraite et pourrait être utilisée par n'importe qui). Ce Worker
 * garde la clé côté serveur (secret Cloudflare) ; l'app appelle seulement
 * cette URL.
 *
 * Bascule automatique entre modèles gratuits : on essaie les modèles dans
 * l'ordre de MODEL_FALLBACK_CHAIN, et on passe au suivant dès qu'un modèle
 * répond "quota dépassé" (429 / RESOURCE_EXHAUSTED). Pas d'état persisté
 * nécessaire : l'API Gemini elle-même nous dit quand un modèle est à sec,
 * donc une bascule par requête suffit (pas besoin de Neon ou d'une autre
 * base pour suivre la consommation).
 */

// Du plus généreux au moins généreux, uniquement des modèles éligibles au
// tier gratuit de l'API Gemini (aucun modèle "pro" payant dans cette liste).
//
// Vérifié en direct le 2026-09-30 via /v1beta/models avec la clé du projet :
// "gemini-2.5-flash-lite" (demandé initialement) est déprécié pour les
// nouvelles clés ("no longer available to new users", message renvoyé par
// l'API elle-même, qui recommande gemini-3.5-flash-lite). La liste
// ci-dessous reflète l'état réel de l'API à cette date, pas une supposition
// figée — à revérifier si Google fait encore évoluer sa gamme de modèles.
const MODEL_FALLBACK_CHAIN = [
  "gemini-3.5-flash-lite", // confirmé fonctionnel en test direct
  "gemini-flash-lite-latest", // alias Google vers le "lite" du moment (reste à jour tout seul)
  "gemini-3.1-flash-lite",
  "gemini-2.5-flash",
  "gemini-flash-latest",
];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-App-Secret",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

/** Convertit l'historique de l'app (role + text) au format Gemini (role + parts). */
function toGeminiContents(history, userMessage) {
  const contents = history.map((turn) => ({
    role: turn.role === "model" ? "model" : "user",
    parts: [{ text: String(turn.text ?? "") }],
  }));
  contents.push({ role: "user", parts: [{ text: userMessage }] });
  return contents;
}

async function callGemini(model, apiKey, systemPrompt, history, userMessage) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents: toGeminiContents(history, userMessage),
      generationConfig: { temperature: 0.9, maxOutputTokens: 200 },
    }),
  });

  if (!res.ok) {
    const errBody = await res.json().catch(() => null);
    const status = errBody?.error?.status;
    const quotaExceeded =
      res.status === 429 || status === "RESOURCE_EXHAUSTED";
    return { ok: false, quotaExceeded, status: res.status, errBody };
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    return { ok: false, quotaExceeded: false, status: 200, errBody: data };
  }
  return { ok: true, text };
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "Méthode non supportée." }, 405);
    }

    if (request.headers.get("X-App-Secret") !== env.APP_SHARED_SECRET) {
      return jsonResponse({ error: "Non autorisé." }, 401);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return jsonResponse({ error: "Corps de requête JSON invalide." }, 400);
    }

    const { systemPrompt, history, userMessage } = payload ?? {};
    if (typeof systemPrompt !== "string" || typeof userMessage !== "string") {
      return jsonResponse(
        { error: "Champs requis manquants (systemPrompt, userMessage)." },
        400,
      );
    }

    const safeHistory = Array.isArray(history) ? history : [];

    for (const model of MODEL_FALLBACK_CHAIN) {
      const result = await callGemini(
        model,
        env.GEMINI_API_KEY,
        systemPrompt,
        safeHistory,
        userMessage,
      );
      if (result.ok) {
        return jsonResponse({ reply: result.text, model });
      }
      if (!result.quotaExceeded) {
        return jsonResponse(
          {
            error: `Erreur du modèle ${model} (statut ${result.status}).`,
          },
          502,
        );
      }
      // Quota épuisé pour ce modèle : on essaie le suivant de la chaîne.
    }

    return jsonResponse(
      { error: "Tous les modèles gratuits sont à quota épuisé pour le moment." },
      503,
    );
  },
};
