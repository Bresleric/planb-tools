// =============================================================================
// extract-document — Edge Function PlanB-Tools
// =============================================================================
// Reçoit { scan_id } via POST.
// Lit la ligne dans `scans`, télécharge le fichier depuis Storage `scans/`,
// appelle Claude Haiku 4.5 Vision avec un prompt selon `type_document`,
// parse le JSON retourné et écrit le détail dans `scan_tracabilite`
// (étiquettes) ou `scan_lignes` (BL/factures).
//
// Date de création : 2026-04-30 (Phase 1 module Scanner)
// =============================================================================

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2'
import Anthropic from 'npm:@anthropic-ai/sdk@0.32.1'

// ---------- Constantes ------------------------------------------------------
const ANTHROPIC_MODEL = 'claude-haiku-4-5-20251001'
// Tarifs Haiku 4.5 (USD / million de tokens) — source : doc reco mars 2026
const PRICE_INPUT_PER_MTOK = 1.0
const PRICE_OUTPUT_PER_MTOK = 5.0
const MAX_OUTPUT_TOKENS = 4096

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ---------- Prompts système -------------------------------------------------
const PROMPT_ETIQUETTE_PRODUIT = `Tu es un expert en analyse d'étiquettes alimentaires et en traçabilité HACCP pour la restauration française. Tu reçois la photo d'une étiquette de produit alimentaire (viande, fromage, BOF, produit transformé, etc.) et tu dois en extraire les informations de traçabilité.

Réponds UNIQUEMENT avec un objet JSON valide, sans aucune balise markdown, sans texte avant ou après. Le JSON doit suivre EXACTEMENT cette structure :

{
  "produit": "string|null",
  "code_article": "string|null",
  "categorie": "string|null",
  "fabricant": "string|null",
  "estampille": "string|null",
  "code_barres": "string|null",
  "lot": "string|null",
  "dlc": "YYYY-MM-DD|null",
  "ddm": "YYYY-MM-DD|null",
  "date_fabrication": "YYYY-MM-DD|null",
  "date_emballage": "YYYY-MM-DD|null",
  "date_abattage": "YYYY-MM-DD|null",
  "poids_net_kg": "number|null",
  "tare_kg": "number|null",
  "temp_min": "number|null",
  "temp_max": "number|null",
  "ingredients": "string|null",
  "allergenes": ["string"],
  "nutrition": {"energie_kj": "number|null", "energie_kcal": "number|null", "matieres_grasses_g": "number|null", "glucides_g": "number|null", "proteines_g": "number|null", "sel_g": "number|null"} | null,
  "origine": "string|null",
  "tracabilite_bovine": {"naissance": "string|null", "elevage": "string|null", "abattage": "string|null", "decoupe": "string|null", "n_traitement": "string|null"} | null,
  "confiance_globale": "number entre 0 et 100",
  "champs_manquants": ["string"],
  "necessite_2eme_photo": "boolean",
  "raison_2eme_photo": "string|null"
}

Règles :
- "produit" : la dénomination commerciale (ex : "Filet de boeuf", "Comté 18 mois")
- "categorie" : une valeur parmi "viande_bovine", "viande_porcine", "viande_volaille", "viande_ovine", "poisson", "fromage", "bof_lait", "fruit_legume", "epicerie", "boisson", "autre"
- "estampille" : numéro d'agrément sanitaire avec code pays, ex : "FR 67.123.001 CE"
- "lot" : numéro/code de lot tel qu'imprimé, sans modification
- Dates au format ISO YYYY-MM-DD. Si l'année est en 2 chiffres (ex : 25/04/26), considérer le siècle 21 (2026 et non 1926).
- "dlc" pour Date Limite de Consommation (produits frais), "ddm" pour Date de Durabilité Minimale (produits secs). Ne pas confondre.
- "poids_net_kg" et "tare_kg" en kilogrammes (convertir si grammes : 250g → 0.25)
- "temp_min"/"temp_max" en degrés Celsius. Si l'étiquette dit "à conserver entre 0 et 4°C", alors temp_min=0 et temp_max=4.
- "allergenes" : tableau de chaînes basses, ex : ["lait", "gluten", "moutarde", "fruits_a_coque"]
- "tracabilite_bovine" : si le produit est de la viande bovine et a un tableau de traçabilité (Né en / Élevé en / Abattu en / Découpé en + numéro de traitement), remplir l'objet. Sinon null.
- "confiance_globale" : ton estimation 0-100 de la fiabilité de l'extraction.
- "champs_manquants" : liste des champs que tu as mis à null car illisibles ou absents.
- "necessite_2eme_photo" : true UNIQUEMENT si l'étiquette renvoie explicitement à une autre face (ex : "voir au dos", "DLC : voir face arrière", "voir emballage")
- "raison_2eme_photo" : explication courte si necessite_2eme_photo est true.

Impératifs :
- Si un champ n'est pas lisible ou n'apparaît pas, mets null. NE JAMAIS inventer une valeur.
- Si tu hésites entre deux interprétations, prends la plus probable et baisse "confiance_globale".
- Pour les chiffres, séparateur décimal = point (ex : 2.5, pas 2,5). Pas de séparateur de milliers.
- N'ajoute aucun champ qui ne soit pas dans le schéma ci-dessus.`

const PROMPT_BL_FACTURE = `Tu es un expert en comptabilité fournisseurs pour la restauration française. Tu reçois la photo d'un bon de livraison ou d'une facture fournisseur et tu dois en extraire toutes les informations utiles à la saisie comptable.

Réponds UNIQUEMENT avec un objet JSON valide, sans markdown ni texte avant ou après :

{
  "fournisseur_nom": "string|null",
  "fournisseur_siret": "string|null",
  "fournisseur_adresse": "string|null",
  "fournisseur_tva_intra": "string|null",
  "nature_document": "BL|facture|avoir|null",
  "numero_document": "string|null",
  "date_document": "YYYY-MM-DD|null",
  "date_livraison": "YYYY-MM-DD|null",
  "lignes": [
    {
      "ligne_num": "number",
      "designation": "string",
      "code_article": "string|null",
      "quantite": "number|null",
      "unite": "string|null",
      "prix_unitaire_ht": "number|null",
      "montant_ht": "number|null",
      "taux_tva": "number|null",
      "montant_tva": "number|null",
      "montant_ttc": "number|null",
      "lot": "string|null",
      "dlc": "YYYY-MM-DD|null"
    }
  ],
  "total_ht": "number|null",
  "total_tva_par_taux": [
    {"taux": "number", "base_ht": "number", "montant": "number"}
  ],
  "total_ttc": "number|null",
  "conditions_paiement": "string|null",
  "echeance": "YYYY-MM-DD|null",
  "confiance_globale": "number entre 0 et 100",
  "champs_manquants": ["string"]
}

Règles :
- Tous les montants en euros sans symbole. Séparateur décimal = point (ex : 1234.56 et non 1.234,56).
- Unités courantes : "kg", "g", "L", "cL", "pce", "btl", "carton", "lot"
- "taux_tva" : 5.5, 10, ou 20 (sans le %)
- Énumérer toutes les lignes avec ligne_num séquentiel à partir de 1.
- "fournisseur_tva_intra" : numéro TVA intracommunautaire (FR + 11 chiffres) si présent.
- Si un champ n'est pas lisible, null. Ne jamais inventer.
- Si plusieurs pages : combiner les lignes de toutes les pages en un seul tableau.`

function getSystemPrompt(typeDocument: string): string {
  switch (typeDocument) {
    case 'etiquette_produit':
      return PROMPT_ETIQUETTE_PRODUIT
    case 'bl_facture':
      return PROMPT_BL_FACTURE
    case 'ticket_caisse':
      throw new Error('Type ticket_caisse pas encore implémenté (Phase 3)')
    default:
      throw new Error(`Type de document non supporté : ${typeDocument}`)
  }
}

// ---------- Helpers ---------------------------------------------------------
function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  })
}

function bytesToBase64(bytes: Uint8Array): string {
  // Conversion robuste pour gros buffers — String.fromCharCode plante au-delà de ~125k.
  let binary = ''
  const chunkSize = 0x8000
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunkSize) as unknown as number[])
  }
  return btoa(binary)
}

async function markError(supabase: SupabaseClient, scanId: string, message: string) {
  await supabase
    .from('scans')
    .update({ statut: 'erreur', claude_erreur_message: message })
    .eq('id', scanId)
}

function extractJson(text: string): unknown {
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('Réponse Claude : aucun objet JSON détecté')
  }
  return JSON.parse(text.substring(start, end + 1))
}

// ---------- Insertions du détail extrait -----------------------------------
async function insertTracabilite(
  supabase: SupabaseClient,
  scanId: string,
  e: Record<string, unknown>,
) {
  const row: Record<string, unknown> = {
    scan_id: scanId,
    produit: e.produit ?? null,
    code_article: e.code_article ?? null,
    categorie: e.categorie ?? null,
    fabricant: e.fabricant ?? null,
    estampille: e.estampille ?? null,
    code_barres: e.code_barres ?? null,
    lot: e.lot ?? null,
    dlc: e.dlc ?? null,
    ddm: e.ddm ?? null,
    date_fabrication: e.date_fabrication ?? null,
    date_emballage: e.date_emballage ?? null,
    date_abattage: e.date_abattage ?? null,
    poids_net_kg: e.poids_net_kg ?? null,
    tare_kg: e.tare_kg ?? null,
    temp_min: e.temp_min ?? null,
    temp_max: e.temp_max ?? null,
    ingredients: e.ingredients ?? null,
    allergenes: Array.isArray(e.allergenes) ? e.allergenes : null,
    nutrition: e.nutrition ?? null,
    origine: e.origine ?? null,
    tracabilite_bovine_jsonb: e.tracabilite_bovine ?? null,
    confiance: typeof e.confiance_globale === 'number' ? e.confiance_globale : null,
  }
  const { error } = await supabase.from('scan_tracabilite').insert(row)
  if (error) throw new Error(`INSERT scan_tracabilite : ${error.message}`)
}

async function insertLignes(
  supabase: SupabaseClient,
  scanId: string,
  e: Record<string, unknown>,
) {
  const lignes = Array.isArray(e.lignes) ? (e.lignes as Record<string, unknown>[]) : []
  if (lignes.length === 0) return
  const rows = lignes.map((l, idx) => ({
    scan_id: scanId,
    ligne_num: typeof l.ligne_num === 'number' ? l.ligne_num : idx + 1,
    designation: l.designation ?? null,
    code_article: l.code_article ?? null,
    quantite: l.quantite ?? null,
    unite: l.unite ?? null,
    prix_unitaire_ht: l.prix_unitaire_ht ?? null,
    montant_ht: l.montant_ht ?? null,
    taux_tva: l.taux_tva ?? null,
    montant_tva: l.montant_tva ?? null,
    montant_ttc: l.montant_ttc ?? null,
    lot: l.lot ?? null,
    dlc: l.dlc ?? null,
    confiance: typeof e.confiance_globale === 'number' ? e.confiance_globale : null,
  }))
  const { error } = await supabase.from('scan_lignes').insert(rows)
  if (error) throw new Error(`INSERT scan_lignes : ${error.message}`)
}

// ---------- Handler principal ----------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS, status: 204 })
  }
  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'Méthode non autorisée (POST attendu)' }, 405)
  }

  let scanId: string | undefined
  try {
    const body = await req.json().catch(() => ({}))
    scanId = body?.scan_id
    if (!scanId || typeof scanId !== 'string') {
      return jsonResponse({ ok: false, error: 'scan_id manquant dans le body JSON' }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ ok: false, error: 'SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY manquant' }, 500)
    }
    if (!anthropicKey) {
      return jsonResponse({ ok: false, error: 'ANTHROPIC_API_KEY manquant dans les secrets' }, 500)
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    })

    // 1. Récupérer la ligne scans
    const { data: scan, error: scanErr } = await supabase
      .from('scans')
      .select('*')
      .eq('id', scanId)
      .single()
    if (scanErr || !scan) {
      return jsonResponse({ ok: false, error: `Scan introuvable : ${scanErr?.message ?? 'inconnu'}` }, 404)
    }

    if (!['en_attente_extraction', 'erreur'].includes(scan.statut)) {
      return jsonResponse({ ok: false, error: `Scan déjà traité (statut : ${scan.statut})` }, 409)
    }

    // 2. Marquer en_cours
    await supabase.from('scans').update({ statut: 'extraction_en_cours' }).eq('id', scanId)

    // 3. Télécharger le fichier
    const { data: fileBlob, error: dlErr } = await supabase
      .storage
      .from('scans')
      .download(scan.storage_path)
    if (dlErr || !fileBlob) {
      await markError(supabase, scanId, `Téléchargement Storage : ${dlErr?.message ?? 'inconnu'}`)
      return jsonResponse({ ok: false, error: 'Téléchargement du fichier échoué' }, 500)
    }
    const buffer = await fileBlob.arrayBuffer()
    const base64 = bytesToBase64(new Uint8Array(buffer))
    const mediaType = scan.mime_type ?? 'image/jpeg'
    const isPdf = mediaType === 'application/pdf'

    // 4. Préparer le prompt
    let systemPrompt: string
    try {
      systemPrompt = getSystemPrompt(scan.type_document)
    } catch (err) {
      await markError(supabase, scanId, (err as Error).message)
      return jsonResponse({ ok: false, error: (err as Error).message }, 400)
    }
    const userText = 'Extrais les données de ce document selon le format JSON demandé. Réponds uniquement avec le JSON, sans markdown ni texte autour.'

    // 5. Appel Claude Vision
    const anthropic = new Anthropic({ apiKey: anthropicKey })
    let extraction: Record<string, unknown>
    let tokensIn = 0
    let tokensOut = 0
    try {
      const message = await anthropic.messages.create({
        model: ANTHROPIC_MODEL,
        max_tokens: MAX_OUTPUT_TOKENS,
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: isPdf ? 'document' : 'image',
                source: {
                  type: 'base64',
                  media_type: mediaType,
                  data: base64,
                },
              },
              { type: 'text', text: userText },
            ] as unknown as Anthropic.MessageParam['content'],
          },
        ],
      })

      tokensIn = message.usage.input_tokens
      tokensOut = message.usage.output_tokens

      const firstBlock = message.content[0]
      if (!firstBlock || firstBlock.type !== 'text') {
        throw new Error("Réponse Claude sans bloc texte")
      }
      extraction = extractJson(firstBlock.text) as Record<string, unknown>
    } catch (err) {
      const msg = (err as Error).message
      await markError(supabase, scanId, `Anthropic ou parsing JSON : ${msg}`)
      return jsonResponse({ ok: false, error: msg }, 500)
    }

    // 6. Calcul du coût
    const costUsd =
      (tokensIn / 1_000_000) * PRICE_INPUT_PER_MTOK +
      (tokensOut / 1_000_000) * PRICE_OUTPUT_PER_MTOK

    // 7. UPDATE scans avec résultat brut
    const confiance = typeof extraction.confiance_globale === 'number'
      ? extraction.confiance_globale
      : null
    const { error: updErr } = await supabase
      .from('scans')
      .update({
        claude_model: ANTHROPIC_MODEL,
        claude_extraction_jsonb: extraction,
        claude_tokens_in: tokensIn,
        claude_tokens_out: tokensOut,
        claude_cost_usd: costUsd,
        claude_at: new Date().toISOString(),
        confiance_globale: confiance,
        statut: 'extrait',
      })
      .eq('id', scanId)
    if (updErr) {
      return jsonResponse({ ok: false, error: `UPDATE scans : ${updErr.message}` }, 500)
    }

    // 8. Insert détail selon type
    try {
      if (scan.type_document === 'etiquette_produit') {
        await insertTracabilite(supabase, scanId, extraction)
      } else if (scan.type_document === 'bl_facture') {
        await insertLignes(supabase, scanId, extraction)
      }
    } catch (err) {
      const msg = (err as Error).message
      await markError(supabase, scanId, `Insertion détail : ${msg}`)
      return jsonResponse({ ok: false, error: msg }, 500)
    }

    // 9. Statut final = en_attente_validation
    await supabase
      .from('scans')
      .update({ statut: 'en_attente_validation' })
      .eq('id', scanId)

    return jsonResponse({
      ok: true,
      scan_id: scanId,
      type_document: scan.type_document,
      tokens_in: tokensIn,
      tokens_out: tokensOut,
      cost_usd: costUsd,
      confiance_globale: confiance,
      extraction,
    })
  } catch (err) {
    const msg = (err as Error).message
    if (scanId) {
      try {
        const supabase = createClient(
          Deno.env.get('SUPABASE_URL')!,
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
          { auth: { persistSession: false } },
        )
        await markError(supabase, scanId, `Erreur fatale : ${msg}`)
      } catch (_) { /* ignore */ }
    }
    return jsonResponse({ ok: false, error: msg }, 500)
  }
})
