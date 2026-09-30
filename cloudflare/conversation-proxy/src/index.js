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

/**
 * Décalage horaire (en minutes, `local = UTC + décalage`) d'un fuseau donné à
 * un instant donné. Calculé via Intl plutôt que codé en dur, pour rester
 * correct malgré les changements heure d'été/hiver (le tier gratuit Gemini
 * réinitialise son quota RPD à minuit heure du Pacifique, qui bascule entre
 * UTC-7 et UTC-8 selon la période de l'année).
 */
function timeZoneOffsetMinutes(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  })
    .formatToParts(date)
    .reduce((acc, p) => {
      acc[p.type] = p.value;
      return acc;
    }, {});
  const asUtc = Date.UTC(
    Number(parts.year),
    Number(parts.month) - 1,
    Number(parts.day),
    Number(parts.hour),
    Number(parts.minute),
    Number(parts.second),
  );
  return (asUtc - date.getTime()) / 60000;
}

/** Prochain minuit heure du Pacifique (reset du quota gratuit Gemini), en UTC réel. */
function nextPacificMidnightUtc(now) {
  const offsetMin = timeZoneOffsetMinutes(now, "America/Los_Angeles");
  const shifted = new Date(now.getTime() + offsetMin * 60000);
  const y = shifted.getUTCFullYear();
  const m = shifted.getUTCMonth();
  const d = shifted.getUTCDate();
  const nextMidnightShifted = Date.UTC(y, m, d + 1, 0, 0, 0);
  let real = new Date(nextMidnightShifted - offsetMin * 60000);
  // Réajustement si la bascule DST tombe pile ce jour-là (rare, mais évite
  // une erreur d'une heure les 2 jours de l'année où ça peut arriver).
  const offsetAtTarget = timeZoneOffsetMinutes(real, "America/Los_Angeles");
  if (offsetAtTarget !== offsetMin) {
    real = new Date(nextMidnightShifted - offsetAtTarget * 60000);
  }
  return real;
}

/** Formate l'instant de reset en jour + heure lisibles, heure du Laos. */
function formatResetMessage(resetDate) {
  const dateFmt = new Intl.DateTimeFormat("fr-FR", {
    timeZone: "Asia/Vientiane",
    weekday: "long",
    day: "numeric",
    month: "long",
  });
  const timeFmt = new Intl.DateTimeFormat("fr-FR", {
    timeZone: "Asia/Vientiane",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  return `${dateFmt.format(resetDate)} vers ${timeFmt.format(resetDate)} (heure du Laos)`;
}

/**
 * Essaie chaque modèle de MODEL_FALLBACK_CHAIN dans l'ordre via `callFn`
 * (reçoit le nom du modèle, doit retourner le résultat de `callGemini`).
 * Partagé entre le mode conversation et le mode traduction : la logique de
 * bascule/quota-épuisé est identique dans les deux cas.
 */
async function tryModels(callFn) {
  for (const model of MODEL_FALLBACK_CHAIN) {
    const result = await callFn(model);
    if (result.ok) {
      return { ok: true, text: result.text, model };
    }
    if (!result.quotaExceeded) {
      return {
        ok: false,
        status: 502,
        error: `Erreur du modèle ${model} (statut ${result.status}).`,
      };
    }
    // Quota épuisé pour ce modèle : on essaie le suivant de la chaîne.
  }

  const reset = nextPacificMidnightUtc(new Date());
  return {
    ok: false,
    status: 503,
    error:
      "Tous les modèles gratuits Gemini sont à quota épuisé pour aujourd'hui. " +
      `Nouvelle disponibilité estimée : ${formatResetMessage(reset)}.`,
  };
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

    const { mode, systemPrompt, history, userMessage, text } = payload ?? {};

    // Mode traduction FR -> LAO : utilisé pour la relecture des messages du
    // chat (touriste IA et réponse du pro), indépendant du fil de
    // conversation. Partage la même chaîne de modèles et la même gestion de
    // quota épuisé que le mode conversation.
    if (mode === "translate") {
      if (typeof text !== "string" || !text.trim()) {
        return jsonResponse({ error: "Champ requis manquant (text)." }, 400);
      }
      const translatePrompt =
        "Tu es un traducteur français vers lao. Traduis fidèlement la " +
        "phrase suivante en lao, en écriture lao uniquement, sans " +
        "translittération et sans aucun commentaire ni guillemets : " +
        "réponds uniquement avec la traduction.";
      const result = await tryModels((model) =>
        callGemini(model, env.GEMINI_API_KEY, translatePrompt, [], text),
      );
      if (!result.ok) return jsonResponse({ error: result.error }, result.status);
      return jsonResponse({ translation: result.text.trim(), model: result.model });
    }

    if (typeof systemPrompt !== "string" || typeof userMessage !== "string") {
      return jsonResponse(
        { error: "Champs requis manquants (systemPrompt, userMessage)." },
        400,
      );
    }

    const safeHistory = Array.isArray(history) ? history : [];

    const result = await tryModels((model) =>
      callGemini(model, env.GEMINI_API_KEY, systemPrompt, safeHistory, userMessage),
    );
    if (!result.ok) return jsonResponse({ error: result.error }, result.status);
    return jsonResponse({ reply: result.text, model: result.model });
  },
};
