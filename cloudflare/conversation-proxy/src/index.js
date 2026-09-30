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
 * échoue, quelle que soit la raison. Pas d'état persisté nécessaire : l'API
 * Gemini elle-même nous dit à chaque requête quels modèles répondent, donc
 * une bascule par requête suffit (pas besoin de Neon ou d'une autre base
 * pour suivre la consommation).
 *
 * Astuce non évidente (diagnostiquée le 2026-09-30 via des logs temporaires
 * `wrangler tail`) : un Worker Cloudflare classique s'exécute depuis le
 * datacenter le plus proche du client à CHAQUE requête, qui peut varier d'un
 * appel à l'autre. Or l'API Gemini gratuite (clé AI Studio) refuse les
 * requêtes venant de certains pays avec l'erreur trompeuse "User location is
 * not supported for the API use" (HTTP 400 FAILED_PRECONDITION — rien à voir
 * avec le quota). Ça donnait l'impression d'une bascule de modèles cassée :
 * en réalité TOUS les modèles échouaient à cause du datacenter Cloudflare du
 * moment, et ça ne remarchait que quand le hasard retombait sur un
 * datacenter dans un pays accepté par Google. D'où l'appel à Gemini
 * maintenant fait depuis le Durable Object `GeminiCaller` ci-dessous, épinglé
 * une fois pour toutes sur la région "wnam" (Amérique du Nord Ouest,
 * acceptée par Gemini) via `locationHint` — le point d'entrée du Worker peut
 * toujours répondre depuis le datacenter le plus proche du client, seul
 * l'appel sortant vers Gemini est stabilisé.
 */

// Du plus généreux au moins généreux, uniquement des modèles éligibles au
// tier gratuit de l'API Gemini (aucun modèle "pro" payant dans cette liste).
//
// Vérifié en direct le 2026-09-30 via /v1beta/models avec la clé du projet :
// "gemini-2.5-flash-lite" (demandé initialement) est déprécié pour les
// nouvelles clés ("no longer available to new users", message renvoyé par
// l'API elle-même, qui recommande gemini-3.5-flash-lite). "gemini-2.5-flash"
// est déprécié de la même façon depuis (message renvoyé par l'API :
// recommande gemini-3.8-flash), remplacé ci-dessous. Liste à revérifier si
// Google fait encore évoluer sa gamme de modèles.
const MODEL_FALLBACK_CHAIN = [
  "gemini-3.5-flash-lite", // confirmé fonctionnel en test direct
  "gemini-flash-lite-latest", // alias Google vers le "lite" du moment (reste à jour tout seul)
  "gemini-3.1-flash-lite",
  "gemini-3.8-flash", // remplace gemini-2.5-flash, déprécié (404 confirmé le 2026-09-30)
  "gemini-flash-latest",
];

// Rappel explicite anti-dérive vers le thaï : le lao et le thaï sont deux
// langues distinctes avec deux alphabets Unicode différents (lao : U+0E80 à
// U+0EFF ; thaï : U+0E00 à U+0E7F) mais proches (phonologie et vocabulaire
// voisins, très peu de contenu lao dans les données d'entraînement des LLM
// comparé au thaï). Observé en direct le 2026-09-30 : sans ce garde-fou,
// Gemini répond occasionnellement en écriture THAÏE alors que le prompt
// demande du lao — un professionnel lao ne pourrait pas le lire. Ce rappel
// est ajouté à tous les prompts qui demandent une sortie en lao.
const LAO_NOT_THAI_GUARD =
  " IMPORTANT : le lao (ພາສາລາວ) et le thaï (ภาษาไทย) sont deux langues et " +
  "deux alphabets DIFFÉRENTS, même s'ils se ressemblent. N'utilise JAMAIS " +
  "l'alphabet thaï, même pour un seul mot. Utilise UNIQUEMENT l'alphabet " +
  "lao (par exemple : ສະບາຍດີ, ຂອບໃຈ, ເດີນທາງ — jamais ภาษาไทย, สวัสดี ni " +
  "เดินทาง). Si un mot te vient spontanément en thaï, cherche le mot lao " +
  "correct à la place. Relis ta réponse avant de la donner : elle ne doit " +
  "contenir STRICTEMENT AUCUN caractère thaï, pas même un seul.";

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

async function callGemini(
  model,
  apiKey,
  systemPrompt,
  history,
  userMessage,
  generationConfigOverrides = {},
) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents: toGeminiContents(history, userMessage),
      generationConfig: {
        temperature: 0.9,
        maxOutputTokens: 200,
        ...generationConfigOverrides,
      },
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
  let sawQuotaExceeded = false;
  let lastNonQuotaError = null;

  for (const model of MODEL_FALLBACK_CHAIN) {
    const result = await callFn(model);
    if (result.ok) {
      return { ok: true, text: result.text, model };
    }
    if (result.quotaExceeded) {
      sawQuotaExceeded = true;
    } else {
      // Erreur ponctuelle sur ce modèle précis (404 sur un nom de modèle
      // déprécié, 400, etc.) : on ne s'arrête pas là pour autant. D'autres
      // modèles de la chaîne peuvent avoir un quota encore disponible, donc
      // on continue à essayer le suivant plutôt que d'abandonner sur le
      // premier accroc. On ne renvoie cette erreur que si aucun modèle de la
      // chaîne n'a fini par répondre.
      lastNonQuotaError = { model, status: result.status };
    }
  }

  if (!sawQuotaExceeded && lastNonQuotaError) {
    return {
      ok: false,
      status: 502,
      error: `Erreur du modèle ${lastNonQuotaError.model} (statut ${lastNonQuotaError.status}).`,
    };
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

/**
 * Durable Object dont le seul rôle est d'épingler l'appel sortant vers l'API
 * Gemini sur une région Cloudflare fixe (voir le commentaire en haut de
 * fichier sur l'erreur "User location is not supported"). Aucun état stocké
 * : c'est juste un point d'exécution stable, pas une base de données.
 */
export class GeminiCaller {
  constructor(state, env) {
    this.env = env;
  }

  async fetch(request) {
    const { model, systemPrompt, history, userMessage, generationConfigOverrides } =
      await request.json();
    const result = await callGemini(
      model,
      this.env.GEMINI_API_KEY,
      systemPrompt,
      history,
      userMessage,
      generationConfigOverrides ?? {},
    );
    return new Response(JSON.stringify(result));
  }
}

/** Relaie l'appel Gemini au Durable Object épinglé sur "wnam" (voir plus haut). */
async function callGeminiPinned(
  env,
  model,
  systemPrompt,
  history,
  userMessage,
  generationConfigOverrides = {},
) {
  const id = env.GEMINI_CALLER.idFromName("singleton");
  const stub = env.GEMINI_CALLER.get(id, { locationHint: "wnam" });
  const res = await stub.fetch("https://gemini-caller.internal/", {
    method: "POST",
    body: JSON.stringify({
      model,
      systemPrompt,
      history,
      userMessage,
      generationConfigOverrides,
    }),
  });
  return res.json();
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
        "réponds uniquement avec la traduction." +
        LAO_NOT_THAI_GUARD;
      const result = await tryModels((model) =>
        callGeminiPinned(env, model, translatePrompt, [], text),
      );
      if (!result.ok) return jsonResponse({ error: result.error }, result.status);
      return jsonResponse({ translation: result.text.trim(), model: result.model });
    }

    // Mode "compose" : mode "🆘 Je dois parler français" côté app — le pro
    // décrit ce qu'il veut dire (situation ou idée approximative, en
    // français), l'IA formule la phrase française correcte à prononcer, sa
    // phonétique en écriture lao (pour la prononcer) et sa traduction lao
    // (pour vérifier le sens). Réponse forcée en JSON (responseMimeType) pour
    // rester structurée et facile à afficher côté app.
    if (mode === "compose") {
      if (typeof text !== "string" || !text.trim()) {
        return jsonResponse({ error: "Champ requis manquant (text)." }, 400);
      }
      const composePrompt =
        "Tu aides un professionnel lao du tourisme à formuler une phrase " +
        "en français correcte et naturelle à dire à un touriste " +
        "francophone, à partir d'une description approximative de ce " +
        "qu'il veut dire (en français ou en lao). Réponds UNIQUEMENT avec " +
        "un objet JSON, sans texte autour, avec exactement ces clés : " +
        '"french" (la phrase en français à dire, naturelle et polie), ' +
        '"phonetic" (transcription en écriture lao de la PRONONCIATION de ' +
        "cette phrase française, pour aider un lecteur lao à la " +
        'prononcer), "meaning" (traduction du sens de cette phrase en lao, ' +
        "en écriture lao normale)." +
        LAO_NOT_THAI_GUARD;
      const result = await tryModels((model) =>
        callGeminiPinned(env, model, composePrompt, [], text, {
          responseMimeType: "application/json",
          maxOutputTokens: 300,
        }),
      );
      if (!result.ok) return jsonResponse({ error: result.error }, result.status);
      let parsed;
      try {
        parsed = JSON.parse(result.text);
      } catch {
        return jsonResponse({ error: "Réponse invalide de l'IA." }, 502);
      }
      if (
        typeof parsed.french !== "string" ||
        typeof parsed.phonetic !== "string" ||
        typeof parsed.meaning !== "string"
      ) {
        return jsonResponse({ error: "Réponse incomplète de l'IA." }, 502);
      }
      return jsonResponse({
        french: parsed.french.trim(),
        phonetic: parsed.phonetic.trim(),
        meaning: parsed.meaning.trim(),
        model: result.model,
      });
    }

    if (typeof systemPrompt !== "string" || typeof userMessage !== "string") {
      return jsonResponse(
        { error: "Champs requis manquants (systemPrompt, userMessage)." },
        400,
      );
    }

    const safeHistory = Array.isArray(history) ? history : [];

    const result = await tryModels((model) =>
      callGeminiPinned(env, model, systemPrompt, safeHistory, userMessage),
    );
    if (!result.ok) return jsonResponse({ error: result.error }, result.status);
    return jsonResponse({ reply: result.text, model: result.model });
  },
};
