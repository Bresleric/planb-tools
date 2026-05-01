// =============================================================================
// reconcile-session — Edge Function PlanB-Tools (Phase 3)
// =============================================================================
// Rapprochement étiquettes ↔ lignes du BL/facture pour une scan_sessions.
// Reçoit { session_id } via POST.
// Appelle Claude Haiku 4.5 pour analyser la cohérence entre les étiquettes
// scannées et les lignes du BL associé. Stocke le résultat dans
// scan_sessions.rapprochement_jsonb et passe la session en statut 'rapprochee'.
// =============================================================================

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2'

const ANTHROPIC_MODEL = 'claude-haiku-4-5-20251001'
const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
const ANTHROPIC_API_VERSION = '2023-06-01'
const PRICE_INPUT_PER_MTOK = 1.0
const PRICE_OUTPUT_PER_MTOK = 5.0
const MAX_OUTPUT_TOKENS = 4096
const ANTHROPIC_TIMEOUT_MS = 60_000

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ---------- Prompt système -------------------------------------------------
const PROMPT_RECONCILIATION = `Tu es un expert en réception de marchandises et contrôle qualité pour la restauration française. Tu reçois deux jeux de données pour une livraison fournisseur :

1. La liste des **étiquettes scannées** par le réceptionnaire (chaque étiquette = un produit physiquement reçu, avec son lot, sa DLC, son poids).
2. La liste des **lignes du BL/facture** du fournisseur (désignation, quantité, unité, prix).

Ton rôle : faire le rapprochement automatique entre ces deux listes et identifier toute incohérence (manquant, écart de poids, double comptage, ligne facturée sans produit reçu, produit reçu sans ligne, etc.).

Réponds UNIQUEMENT avec un objet JSON valide, sans markdown, sans texte autour. Structure attendue :

{
  "matchs": [
    {
      "ligne_bl_num": "number|null",
      "designation_bl": "string|null",
      "qte_bl": "number|null",
      "unite_bl": "string|null",
      "etiquette_ids": ["string (UUID)"],
      "produits_etiquettes": ["string"],
      "qte_etiquettes_total": "number|null",
      "ecart_qte": "number|null",
      "ecart_pct": "number|null",
      "statut_match": "ok|ecart_mineur|ecart_significatif|orphelin"
    }
  ],
  "anomalies": [
    {
      "type": "etiquette_orpheline|ligne_bl_orpheline|ecart_quantite|ecart_dlc|doublon_lot|temperature_non_respectee|autre",
      "severite": "info|warn|critical",
      "description": "string explicative en français",
      "ligne_bl_num": "number|null",
      "etiquette_id": "string|null",
      "etiquette_ids": ["string"]
    }
  ],
  "totaux": {
    "nb_etiquettes": "number",
    "nb_lignes_bl": "number",
    "nb_matchs_complets": "number",
    "nb_anomalies_critical": "number",
    "nb_anomalies_warn": "number",
    "nb_anomalies_info": "number",
    "poids_total_etiquettes_kg": "number|null",
    "montant_total_bl_ht": "number|null"
  },
  "confiance_globale": "number 0-100",
  "resume_humain": "string : 1-2 phrases résumant la qualité du rapprochement"
}

Règles de rapprochement :
- 1 ligne BL peut correspondre à plusieurs étiquettes (ex : ligne "Filet de bœuf 5 kg" = étiquette lot A 2,4 kg + étiquette lot B 2,6 kg).
- 1 étiquette correspond à une seule ligne BL (la plus pertinente par désignation et poids).
- Match par désignation : tolère les variantes orthographiques, abréviations, accents.
- Match par poids/quantité : somme les poids des étiquettes matchées et compare au poids du BL.
- Seuils d'écart : < 1% = "ok", 1-5% = "ecart_mineur", > 5% = "ecart_significatif".
- Si une étiquette ne match aucune ligne BL : ajouter "etiquette_orpheline" en anomalie.
- Si une ligne BL n'a aucune étiquette : ajouter "ligne_bl_orpheline" (peut être normal si le produit n'a pas d'étiquette individuelle, ex : sel, huile, etc.).
- Sévérité : "critical" pour écart > 10% ou ligne payée sans produit livré ; "warn" pour écart 1-10% ou DLC trop courte ; "info" pour écart < 1% ou observation neutre.

Impératifs :
- Ne JAMAIS inventer une étiquette ou une ligne BL.
- Les "etiquette_ids" doivent être les UUIDs exacts fournis dans les données d'entrée.
- "resume_humain" doit être bref, factuel, en français professionnel.
- Si tu hésites, baisse "confiance_globale".`

// ---------- Helpers ---------------------------------------------------------
function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  })
}

function extractJson(text: string): unknown {
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('Réponse Claude : aucun objet JSON détecté')
  }
  return JSON.parse(text.substring(start, end + 1))
}

interface AnthropicResponse {
  content: Array<{ type: string; text?: string }>
  usage: { input_tokens: number; output_tokens: number }
}

async function callAnthropic(apiKey: string, systemPrompt: string, userText: string): Promise<AnthropicResponse> {
  console.log(`[reconcile-session] Anthropic call : userTextLen=${userText.length}`)
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), ANTHROPIC_TIMEOUT_MS)

  let response: Response
  try {
    response = await fetch(ANTHROPIC_API_URL, {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': ANTHROPIC_API_VERSION,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: MAX_OUTPUT_TOKENS,
        system: systemPrompt,
        messages: [{ role: 'user', content: userText }],
      }),
      signal: controller.signal,
    })
  } catch (err) {
    clearTimeout(timeoutId)
    if ((err as Error).name === 'AbortError') {
      throw new Error(`Timeout Anthropic après ${ANTHROPIC_TIMEOUT_MS / 1000}s`)
    }
    throw new Error(`Fetch Anthropic : ${(err as Error).message}`)
  }
  clearTimeout(timeoutId)

  if (!response.ok) {
    const errBody = await response.text().catch(() => '<lecture body échouée>')
    console.error(`[reconcile-session] Anthropic ${response.status} : ${errBody.slice(0, 500)}`)
    throw new Error(`API Anthropic ${response.status} : ${errBody.slice(0, 300)}`)
  }
  const data = await response.json() as AnthropicResponse
  console.log(`[reconcile-session] Anthropic OK : tokens_in=${data.usage.input_tokens}, tokens_out=${data.usage.output_tokens}`)
  return data
}

async function markSessionError(supabase: SupabaseClient, sessionId: string, message: string) {
  console.error(`[reconcile-session] markSessionError(${sessionId}) :`, message)
  await supabase
    .from('scan_sessions')
    .update({ statut: 'bl_scanne', commentaire: `Erreur rapprochement : ${message}` })
    .eq('id', sessionId)
}

// ---------- Handler principal -----------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS, status: 204 })
  }
  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'Méthode non autorisée (POST attendu)' }, 405)
  }

  let sessionId: string | undefined
  try {
    const body = await req.json().catch(() => ({}))
    sessionId = body?.session_id
    if (!sessionId || typeof sessionId !== 'string') {
      return jsonResponse({ ok: false, error: 'session_id manquant' }, 400)
    }
    console.log(`[reconcile-session] START session_id=${sessionId}`)

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const rawAnthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    const anthropicKey = rawAnthropicKey
      ? rawAnthropicKey.replace(/[^\x20-\x7E]/g, '').trim()
      : undefined
    if (!supabaseUrl || !serviceRoleKey || !anthropicKey) {
      return jsonResponse({ ok: false, error: 'Variables d\'environnement manquantes' }, 500)
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } })

    // 1. Charger la session
    const { data: session, error: sessErr } = await supabase
      .from('scan_sessions')
      .select('*')
      .eq('id', sessionId)
      .single()
    if (sessErr || !session) {
      return jsonResponse({ ok: false, error: `Session introuvable : ${sessErr?.message ?? '?'}` }, 404)
    }
    if (!session.bl_facture_scan_id) {
      return jsonResponse({ ok: false, error: 'Aucun BL/facture n\'est lié à cette session' }, 400)
    }

    // Marquer en cours
    await supabase.from('scan_sessions').update({ statut: 'rapprochement_en_cours' }).eq('id', sessionId)

    // 2. Charger les étiquettes de la session (JOIN scans + scan_tracabilite)
    const { data: etiquettesScans, error: scErr } = await supabase
      .from('scans')
      .select('id, type_document, statut, claude_extraction_jsonb, scan_tracabilite(*)')
      .eq('session_id', sessionId)
      .eq('type_document', 'etiquette_produit')
    if (scErr) throw new Error(`Lecture étiquettes : ${scErr.message}`)
    const etiquettes = (etiquettesScans ?? []).map((s: any) => {
      const trac = Array.isArray(s.scan_tracabilite) ? s.scan_tracabilite[0] : s.scan_tracabilite
      return {
        id: s.id,
        produit: trac?.produit ?? null,
        lot: trac?.lot ?? null,
        dlc: trac?.dlc ?? null,
        ddm: trac?.ddm ?? null,
        poids_net_kg: trac?.poids_net_kg ?? null,
        categorie: trac?.categorie ?? null,
        fabricant: trac?.fabricant ?? null,
        origine: trac?.origine ?? null,
        temp_min: trac?.temp_min ?? null,
        temp_max: trac?.temp_max ?? null,
      }
    })
    console.log(`[reconcile-session] ${etiquettes.length} étiquettes chargées`)

    // 3. Charger le BL et ses lignes
    const { data: blScan, error: blErr } = await supabase
      .from('scans')
      .select('id, claude_extraction_jsonb, scan_lignes(*)')
      .eq('id', session.bl_facture_scan_id)
      .single()
    if (blErr || !blScan) throw new Error(`Lecture BL : ${blErr?.message ?? '?'}`)
    const blExtraction = (blScan.claude_extraction_jsonb ?? {}) as Record<string, unknown>
    const blLignes = (Array.isArray(blScan.scan_lignes) ? blScan.scan_lignes : []).map((l: any) => ({
      ligne_num: l.ligne_num,
      designation: l.designation,
      code_article: l.code_article,
      quantite: l.quantite,
      unite: l.unite,
      prix_unitaire_ht: l.prix_unitaire_ht,
      montant_ht: l.montant_ht,
      taux_tva: l.taux_tva,
      lot: l.lot,
      dlc: l.dlc,
    }))
    console.log(`[reconcile-session] ${blLignes.length} lignes BL chargées`)

    if (etiquettes.length === 0 && blLignes.length === 0) {
      return jsonResponse({ ok: false, error: 'Ni étiquette ni ligne BL à rapprocher' }, 400)
    }

    // 4. Construire le contexte
    const userText = `Données de la livraison à rapprocher.

**Fournisseur :** ${session.fournisseur_nom}
**Date réception :** ${session.date_reception}
**Établissement :** ${session.etablissement}
**Total BL/facture :** ${blExtraction.total_ttc ?? '?'} € TTC, ${blExtraction.total_ht ?? '?'} € HT
**N° document :** ${blExtraction.numero_document ?? '?'}

---

**Étiquettes scannées (${etiquettes.length})** :
${JSON.stringify(etiquettes, null, 2)}

---

**Lignes du BL/facture (${blLignes.length})** :
${JSON.stringify(blLignes, null, 2)}

---

Effectue le rapprochement et réponds avec le JSON exact selon le schéma fourni.`

    // 5. Appel Claude
    const claudeResp = await callAnthropic(anthropicKey, PROMPT_RECONCILIATION, userText)
    const tokensIn = claudeResp.usage.input_tokens
    const tokensOut = claudeResp.usage.output_tokens
    const costUsd = (tokensIn / 1_000_000) * PRICE_INPUT_PER_MTOK + (tokensOut / 1_000_000) * PRICE_OUTPUT_PER_MTOK

    const firstBlock = claudeResp.content?.[0]
    if (!firstBlock || firstBlock.type !== 'text' || !firstBlock.text) {
      throw new Error('Réponse Anthropic sans bloc texte')
    }
    const rapprochement = extractJson(firstBlock.text) as Record<string, unknown>
    console.log(`[reconcile-session] Rapprochement OK, ${(rapprochement.anomalies as unknown[] ?? []).length} anomalies`)

    // 6. Décompte des anomalies
    const anomalies = Array.isArray(rapprochement.anomalies) ? rapprochement.anomalies as Array<{ severite?: string }> : []
    const anomaliesCount = anomalies.length

    // 7. UPDATE scan_sessions
    const { error: updErr } = await supabase
      .from('scan_sessions')
      .update({
        statut: 'rapprochee',
        rapprochement_jsonb: rapprochement,
        rapprochement_at: new Date().toISOString(),
        rapprochement_anomalies_count: anomaliesCount,
        rapprochement_tokens_in: tokensIn,
        rapprochement_tokens_out: tokensOut,
        rapprochement_cost_usd: costUsd,
      })
      .eq('id', sessionId)
    if (updErr) {
      throw new Error(`UPDATE scan_sessions : ${updErr.message}`)
    }

    console.log(`[reconcile-session] DONE session_id=${sessionId}, cost=$${costUsd.toFixed(5)}, anomalies=${anomaliesCount}`)
    return jsonResponse({
      ok: true,
      session_id: sessionId,
      tokens_in: tokensIn,
      tokens_out: tokensOut,
      cost_usd: costUsd,
      anomalies_count: anomaliesCount,
      rapprochement,
    })
  } catch (err) {
    const msg = (err as Error).message
    console.error(`[reconcile-session] FATAL :`, msg, (err as Error).stack)
    if (sessionId) {
      try {
        const supabase = createClient(
          Deno.env.get('SUPABASE_URL')!,
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
          { auth: { persistSession: false } },
        )
        await markSessionError(supabase, sessionId, msg)
      } catch (_) { /* ignore */ }
    }
    return jsonResponse({ ok: false, error: msg }, 500)
  }
})
