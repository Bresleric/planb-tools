// ============================================================================
// Contrats Combo -> rh_contrats (reprise unique avant la bascule du 01/01/2027)
// ----------------------------------------------------------------------------
// Deux modes (parametre ?mode=) :
//   - champs (defaut) : NE MODIFIE RIEN. Renvoie la liste des champs des
//     contrats Combo avec leur type (jamais les valeurs), pour verifier le
//     mapping avant import.
//   - import : pour chaque contrat actif rattache a un user PlanB-Tools (nom
//     normalise, meme regle que le veilleur) et SANS contrat deja saisi dans
//     rh_contrats, cree une ligne source = import_combo. Les contrats deja
//     saisis a la main ne sont jamais ecrases.
// Minimisation : seuls type, heures hebdo, dates, equipe et etablissement
// sont lus. Aucune donnee RH sensible n est ecrite.
// Secrets requis : COMBO_API_KEY
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const COMBO_BASE = "https://partner.combohr.com";

// Noms de champs candidats (le format exact de l API Combo est a confirmer
// avec le mode champs ; ajuster ces listes si besoin)
const CHAMPS_HEURES = ["weekly_hours", "contract_hours", "hours_per_week", "weekly_duration", "working_hours", "hours"];
const CHAMPS_DEBUT = ["start_date", "starts_at", "contract_start_date", "begin_date"];
const CHAMPS_FIN = ["end_date", "ends_at", "contract_end_date"];
const CHAMPS_TYPE = ["contract_type", "type", "kind", "contract_kind"];
const CHAMPS_EQUIPE = ["team_name", "team", "position_name", "job_title"];

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
  if (t.includes("cuisine")) return "cuisine";
  if (t.includes("salle") || t.includes("service")) return "salle";
  return null;
}

function mapType(v: unknown): string {
  const t = String(v || "").toLowerCase();
  if (t.includes("cdd")) return "cdd";
  if (t.includes("extra") || t.includes("vacat")) return "extra";
  if (t.includes("appren") || t.includes("altern")) return "apprentissage";
  if (t.includes("stag") || t.includes("intern")) return "stage";
  return "cdi";
}

function premier(obj: Record<string, unknown>, champs: string[]): unknown {
  for (const c of champs) if (obj[c] !== undefined && obj[c] !== null && obj[c] !== "") return obj[c];
  return null;
}

// Heures : nombre (35, 39) ou minutes (2340) ou "35:00"
function heures(v: unknown): number | null {
  if (v === null || v === undefined) return null;
  if (typeof v === "string" && v.includes(":")) {
    const [h, m] = v.split(":").map(Number);
    return isNaN(h) ? null : h + (m || 0) / 60;
  }
  const n = Number(v);
  if (isNaN(n)) return null;
  return n > 60 ? Math.round(n / 60 * 100) / 100 : n;
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
  const mode = new URL(req.url).searchParams.get("mode") || "champs";
  const summary = {
    mode, locations: 0, contrats_vus: 0,
    champs: {} as Record<string, string>,
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
      for (const c of contracts) {
        summary.contrats_vus++;
        // Mode champs : noms + types uniquement, jamais les valeurs
        for (const [k, v] of Object.entries(c)) {
          if (!summary.champs[k]) summary.champs[k] = v === null ? "null" : Array.isArray(v) ? "array" : typeof v;
        }
        if (mode !== "import") continue;

        const nom = `${c.firstname || ""} ${c.lastname || ""}`.trim();
        if (!nom || !etab) continue;
        const user = parNom.get(normName(nom));
        if (!user) { summary.sans_user.push(nom); continue; }
        if (vus.has(user.id)) continue;
        vus.add(user.id);
        if (dejaSaisis.has(user.id)) { summary.deja_saisis++; continue; }

        const h = heures(premier(c, CHAMPS_HEURES));
        const debut = dateIso(premier(c, CHAMPS_DEBUT));
        if (h === null || !debut) { summary.incomplets.push(nom); continue; }

        const equipe = mapEquipe(premier(c, CHAMPS_EQUIPE)) || mapEquipe(user.equipe) || "autre";
        const { error: iErr } = await supabase.from("rh_contrats").insert({
          user_id: user.id,
          etablissement: etab,
          equipe,
          type_contrat: mapType(premier(c, CHAMPS_TYPE)),
          heures_hebdo: Math.min(48, h),
          date_debut: debut,
          date_fin: dateIso(premier(c, CHAMPS_FIN)),
          source: "import_combo",
          notes: "Repris de Combo, a verifier",
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
