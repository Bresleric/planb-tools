// ============================================================================
// Planning Combo -> planning_combo (reflet automatique jusqu a la bascule)
// ----------------------------------------------------------------------------
// Lance par pg_cron plusieurs fois par jour, comme le veilleur.
// Recopie les horaires Combo de 2 semaines en arriere a 8 semaines en avant,
// sans jamais depasser le 31/12/2026 : a partir du 01/01/2027, PlanB-Tools
// devient la source du planning.
// Ne touche ni au brouillon (planning_shifts), ni au publie (planning_publies).
// Parametres facultatifs : ?start=AAAA-MM-JJ&end=AAAA-MM-JJ (fin EXCLUE, comme Combo).
// Minimisation : nom, etablissement, equipe, horaires, pause et note uniquement.
// Le resume ne renvoie que les noms des champs Combo, jamais leurs valeurs.
// Secrets requis : COMBO_API_KEY
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const COMBO_BASE = "https://partner.combohr.com";
const PARIS = "Europe/Paris";
const BASCULE = "2027-01-01";
const SEMAINES_AVANT = 2;
const SEMAINES_APRES = 8;

function normName(s: string): string {
  return s.trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .split(/\s+/).sort().join(" ");
}

function mapEtab(locationName: string): string | null {
  const n = locationName.toLowerCase();
  if (n.includes("freddy")) return "freddy";
  if (n.includes("liesel")) return "liesel";
  return null;
}

function mapEquipe(teamName: string | null): string {
  const t = (teamName || "").toLowerCase();
  if (t.includes("plonge")) return "plonge";
  if (t.includes("cuisine")) return "cuisine";
  if (t.includes("salle") || t.includes("service")) return "salle";
  return "autre";
}

function parisDate(offsetDays = 0): string {
  const d = new Date(Date.now() + offsetDays * 86400000);
  return new Intl.DateTimeFormat("fr-CA", { timeZone: PARIS }).format(d);
}

function toHM(ts: string | null): string | null {
  if (!ts) return null;
  if (/(Z|[+-]\d{2}:?\d{2})$/.test(ts)) {
    const d = new Date(ts);
    return new Intl.DateTimeFormat("fr-FR", { timeZone: PARIS, hour: "2-digit", minute: "2-digit", hour12: false }).format(d).replace("h", ":");
  }
  const m = ts.match(/T?(\d{2}:\d{2})/g);
  return m ? m[m.length - 1].replace("T", "") : null;
}

async function comboGet(path: string): Promise<unknown> {
  const res = await fetch(COMBO_BASE + path, {
    headers: { Authorization: `Bearer ${Deno.env.get("COMBO_API_KEY")}` },
  });
  if (!res.ok) throw new Error(`Combo ${path} -> HTTP ${res.status}`);
  return await res.json();
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  let start = url.searchParams.get("start") || parisDate(-7 * SEMAINES_AVANT);
  let end = url.searchParams.get("end") || parisDate(7 * SEMAINES_APRES);
  if (end > BASCULE) end = BASCULE;
  const summary = {
    start, end, locations: 0,
    horaires: {} as Record<string, number>,
    par_semaine: {} as Record<string, number>,
    champs_combo: {} as Record<string, string>,
    non_publies_ignores: 0, sans_horaire: 0,
    sans_compte: [] as string[], erreurs: [] as string[],
  };
  try {
    if (start >= end) return new Response(JSON.stringify(summary, null, 2), { headers: { "Content-Type": "application/json" } });

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const [{ data: users, error: uErr }, { data: mapping, error: mErr }] = await Promise.all([
      supabase.from("users").select("id, nom").eq("actif", true),
      supabase.from("combo_user_mapping").select("combo_collaborateur_nom, user_id"),
    ]);
    if (uErr) throw uErr;
    if (mErr) throw mErr;
    const userByName = new Map<string, string>();
    (users || []).forEach((u) => userByName.set(normName(u.nom || ""), u.id));
    const actifs = new Set((users || []).map((u) => u.id));
    (mapping || []).forEach((m) => {
      if (m.user_id && actifs.has(m.user_id)) userByName.set(normName(m.combo_collaborateur_nom || ""), m.user_id);
    });

    const locations = (await comboGet("/api/v1/locations")) as Array<{ id: string; name: string }>;
    summary.locations = locations.length;
    const synchronise_le = new Date().toISOString();
    const inconnus = new Set<string>();

    for (const loc of locations) {
      const etab = mapEtab(loc.name);
      if (!etab) continue;
      try {
        const shifts = (await comboGet(
          `/api/v1/plannings?start_date=${start}&end_date=${end}&location_id=${encodeURIComponent(loc.id)}`,
        )) as Array<Record<string, unknown>>;

        const rows = [];
        for (const s of shifts) {
          for (const [k, v] of Object.entries(s)) {
            if (!summary.champs_combo[k]) summary.champs_combo[k] = v === null ? "null" : Array.isArray(v) ? "array" : typeof v;
          }
          if (s.published === false || s.is_published === false) { summary.non_publies_ignores++; continue; }
          const nom = `${s.firstname || ""} ${s.lastname || ""}`.trim();
          const debut = toHM(s.starts_at as string | null);
          const fin = toHM(s.ends_at as string | null);
          const date = String(s.date || "");
          if (!nom || !date) continue;
          if (!debut || !fin || debut === fin) { summary.sans_horaire++; continue; }
          const user_id = userByName.get(normName(nom)) || null;
          if (!user_id) inconnus.add(nom);
          rows.push({
            user_id, nom_combo: nom, date_service: date, etablissement: etab, nature: "travail",
            equipe: mapEquipe(s.team_name as string | null),
            heure_debut: debut, heure_fin: fin,
            pause_minutes: Number(s.break_duration) || 0,
            poste: String(s.note || "").trim() || null,
            synchronise_le,
          });
        }

        // Combo ne renvoie rien : on garde le dernier reflet plutot que de tout vider
        if (rows.length === 0) { summary.horaires[etab] = 0; continue; }

        const { error: dErr } = await supabase.from("planning_combo").delete()
          .eq("etablissement", etab).gte("date_service", start).lt("date_service", end);
        if (dErr) throw dErr;
        const { error: iErr } = await supabase.from("planning_combo").insert(rows);
        if (iErr) throw iErr;
        summary.horaires[etab] = rows.length;
        for (const r of rows) {
          const d = new Date(r.date_service + "T12:00:00Z");
          d.setUTCDate(d.getUTCDate() - (d.getUTCDay() + 6) % 7);
          const lundi = d.toISOString().slice(0, 10);
          summary.par_semaine[lundi] = (summary.par_semaine[lundi] || 0) + 1;
        }
      } catch (pErr) {
        summary.erreurs.push(`planning ${etab}: ${String(pErr?.message || pErr)}`);
      }
    }
    summary.sans_compte = [...inconnus].sort();
    return new Response(JSON.stringify(summary, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    summary.erreurs.push(String(err?.message || err));
    return new Response(JSON.stringify(summary, null, 2), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
