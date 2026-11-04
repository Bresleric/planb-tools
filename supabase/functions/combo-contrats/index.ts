// ============================================================================
// Contrats Combo -> rh_contrats (reprise unique avant la bascule du 01/01/2027)
// ----------------------------------------------------------------------------
// Trois modes (?mode= ou corps JSON {"mode": "..."}) :
//   - champs : NE MODIFIE RIEN. Renvoie la liste des champs des
//     contrats Combo avec leur type (jamais les valeurs), pour verifier le
//     mapping avant import.
//   - apercu (defaut) : NE MODIFIE RIEN. Compte les valeurs distinctes de quelques
//     champs non sensibles (heures, type, fonction), sans aucun nom : sert a
//     confirmer l unite de contract_time avant import.
//   - import : pour chaque contrat actif rattache a un user PlanB-Tools (nom
//     normalise, meme regle que le veilleur) et SANS contrat deja saisi dans
//     rh_contrats, cree une ligne source = import_combo. Les contrats deja
//     saisis a la main ne sont jamais ecrases.
// Minimisation : seuls type, heures hebdo, dates, equipe et etablissement
// sont ecrits. Aucune donnee RH sensible n est lue ni ecrite.
// Secrets requis : COMBO_API_KEY
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const COMBO_BASE = "https://partner.combohr.com";

// Champs non sensibles comptes par le mode apercu (constat API du 04/11/2026).
// L API renvoie aussi NIR, adresse et salaire : ils ne sont jamais lus ici.
const CHAMPS_APERCU = ["contract_time", "contract_type", "working_days_in_week", "daily_worker", "function", "role"];

function normName(s: string): string {
  return s.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    .split(/\s+/).sort().join(" ");
}

function mapEtab(locationName: string): string | null {
  const n = locationName.toLowerCase();
  if (n.includes("freddy")) return "freddy";
  if (n.includes("liesel")) return "liesel";
  return null;
}

function mapEquipe(v: unknown): string | null {
  const t = String(v || "").toLowerCase();
  if (!t) return null;
  if (t.includes("plonge")) return "plonge";
  if (t.includes("cuisin") || t.includes("commis")) return "cuisine";
  if (t.includes("salle") || t.includes("service") || t.includes("serv") || t.includes("rang")) return "salle";
  return null;
}

// Valeurs vues dans Combo le 04/11/2026 : CDI, seasonal, null.
// Type vide ou inconnu : pas de CDI par defaut, le contrat part dans "incomplets".
function mapType(v: unknown): string | null {
  const t = String(v || "").toLowerCase();
  if (t.includes("cdi")) return "cdi";
  if (t.includes("cdd") || t.includes("seasonal")) return "cdd";
  if (t.includes("extra") || t.includes("vacat")) return "extra";
  if (t.includes("appren") || t.includes("altern")) return "apprentissage";
  if (t.includes("stag") || t.includes("intern")) return "stage";
  return null;
}

// contract_time = heures par semaine (apercu du 04/11/2026 : 12 a 39, et un 50).
// Une valeur hors de 0-48 n est jamais corrigee en silence : "incomplets".
function heures(v: unknown): number | null {
  const n = Number(v);
  if (v === null || v === undefined || isNaN(n) || n < 0 || n > 48) return null;
  return n;
}

function dateIso(v: unknown): string | null {
  const m = String(v || "").match(/^\d{4}-\d{2}-\d{2}/);
  return m ? m[0] : null;
}

async function comboGet(path: string): Promise<unknown> {
  const res = await fetch(COMBO_BASE + path, {
    headers: { Authorization: `Bearer ${Deno.env.get("COMBO_API_KEY")}` },
  });
  if (!res.ok) throw new Error(`Combo ${path} -> HTTP ${res.status}`);
  return await res.json();
}

Deno.serve(async (req) => {
  // Mode lu dans l URL ou dans le corps JSON (le panneau Test envoie le corps).
  // Sans mode explicite : apercu, qui ne modifie rien.
  const corps = await req.json().catch(() => ({}));
  const mode = new URL(req.url).searchParams.get("mode") || corps?.mode || "apercu";
  const summary = {
    mode, locations: 0, contrats_vus: 0,
    champs: {} as Record<string, string>,
    apercu: {} as Record<string, Record<string, number>>,
    importes: [] as string[], deja_saisis: 0,
    sans_user: [] as string[], incomplets: [] as string[],
    erreurs: [] as string[],
  };
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: users, error: uErr } = await supabase.from("users").select("id, nom, equipe").eq("actif", true);
    if (uErr) throw uErr;
    const parNom = new Map((users || []).map((u) => [normName(u.nom || ""), u]));

    const { data: existants, error: eErr } = await supabase.from("rh_contrats").select("user_id");
    if (eErr) throw eErr;
    const dejaSaisis = new Set((existants || []).map((c) => c.user_id));

    const locations = (await comboGet("/api/v1/locations")) as Array<{ id: string; name: string }>;
    summary.locations = locations.length;

    const vus = new Set<string>();
    for (const loc of locations) {
      const etab = mapEtab(loc.name);
      const contracts = (await comboGet(`/api/v1/contracts?location_id=${encodeURIComponent(loc.id)}`)) as Array<Record<string, unknown>>;
      // Le contrat le plus recent d abord : c est lui qui est retenu pour le salarie
      contracts.sort((a, b) => String(b.start_date || "").localeCompare(String(a.start_date || "")));
      for (const c of contracts) {
        summary.contrats_vus++;
        // Mode champs : noms + types uniquement, jamais les valeurs
        for (const [k, v] of Object.entries(c)) {
          if (!summary.champs[k]) summary.champs[k] = v === null ? "null" : Array.isArray(v) ? "array" : typeof v;
        }
        if (mode === "apercu") {
          for (const k of CHAMPS_APERCU) {
            const compte = summary.apercu[k] = summary.apercu[k] || {};
            const val = String(c[k]);
            compte[val] = (compte[val] || 0) + 1;
          }
        }
        if (mode !== "import") continue;

        const nom = `${c.firstname || ""} ${c.lastname || ""}`.trim();
        if (!nom || !etab) continue;
        const user = parNom.get(normName(nom));
        if (!user) { summary.sans_user.push(nom); continue; }
        if (vus.has(user.id)) continue;
        vus.add(user.id);
        if (dejaSaisis.has(user.id)) { summary.deja_saisis++; continue; }

        const h = heures(c.contract_time);
        const debut = dateIso(c.start_date);
        const type = mapType(c.contract_type);
        if (h === null || !debut || !type) {
          const manque = [h === null ? `heures (${c.contract_time})` : "", !debut ? "date de debut" : "", !type ? "type de contrat" : ""].filter(Boolean).join(", ");
          summary.incomplets.push(`${nom} : ${manque}`);
          continue;
        }

        const equipe = mapEquipe(user.equipe) || mapEquipe(c.function) || "autre";
        const { error: iErr } = await supabase.from("rh_contrats").insert({
          user_id: user.id,
          etablissement: etab,
          equipe,
          type_contrat: type,
          heures_hebdo: h,
          date_debut: debut,
          date_fin: dateIso(c.end_date),
          source: "import_combo",
          notes: String(c.contract_type).toLowerCase() === "seasonal" ? "Saisonnier. Repris de Combo, a verifier" : "Repris de Combo, a verifier",
          saisi_par_nom: "Import Combo",
        });
        if (iErr) { summary.erreurs.push(`${nom}: ${iErr.message}`); continue; }
        summary.importes.push(`${nom} (${etab}, ${h} h)`);
      }
    }

    return new Response(JSON.stringify(summary, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    summary.erreurs.push(String(err?.message || err));
    return new Response(JSON.stringify(summary, null, 2), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
