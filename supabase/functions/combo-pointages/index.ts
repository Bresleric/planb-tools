// ============================================================================
// Pointages Combo — planning prevu + badgeages + heures retenues
// ----------------------------------------------------------------------------
// Lance par pg_cron (2 fois par jour, apres le veilleur) :
//   - recupere les shifts Combo des 2 derniers jours (J-2 et J-1, heure de Paris)
//     via GET /api/v1/plannings (meme endpoint que le veilleur)
//   - remplace les lignes correspondantes de combo_pointages
//   - consommees par le rapport journalier (bloc Planning vs pointage)
// Trois niveaux par shift :
//   planifie = starts_at / ends_at / break_duration
//   pointe   = badgeages bruts (events clock_in / clock_out / break_*)
//   valide   = real_starts_at / real_ends_at / real_break_duration
//              ATTENTION : sans badgeage, Combo recopie le prevu dans le reel.
//              "Non badge" se lit donc sur debut_pointe IS NULL, pas sur le reel.
// NB API Combo : end_date est EXCLUE (start=J, end=J+1 renvoie le seul jour J).
// Parametres optionnels (rattrapage) : ?start=AAAA-MM-JJ&end=AAAA-MM-JJ (fin exclue)
// Minimisation : nom, etablissement, equipe et horaires uniquement.
// Secrets requis : COMBO_API_KEY
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const COMBO_BASE = "https://partner.combohr.com";
const PARIS = "Europe/Paris";
const SOURCE = "api-combo";

function parisDate(offsetDays = 0): string {
  const d = new Date(Date.now() + offsetDays * 86400000);
  return new Intl.DateTimeFormat("fr-CA", { timeZone: PARIS }).format(d); // YYYY-MM-DD
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
  return t ? t.replace(/\s+/g, "_") : "salle";
}

function normName(s: string): string {
  return s.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    .split(/\s+/).sort().join(" ");
}

function minutesEntre(a: string | null, b: string | null): number | null {
  if (!a || !b) return null;
  return Math.round((new Date(b).getTime() - new Date(a).getTime()) / 60000);
}

async function comboGet(path: string): Promise<unknown> {
  const res = await fetch(COMBO_BASE + path, {
    headers: { Authorization: `Bearer ${Deno.env.get("COMBO_API_KEY")}` },
  });
  if (!res.ok) throw new Error(`Combo ${path} -> HTTP ${res.status}`);
  return await res.json();
}

type ComboEvent = { event_type: string; event_occurred_at: string };
type ComboShift = {
  date: string; starts_at: string | null; ends_at: string | null; break_duration: number | null;
  real_starts_at: string | null; real_ends_at: string | null; real_break_duration: number | null;
  firstname: string | null; lastname: string | null; team_name: string | null;
  events: ComboEvent[] | null;
};

// Badgeages bruts -> premiere arrivee, derniere sortie, total des pauses badgees
function lireBadgeages(events: ComboEvent[] | null) {
  const ev = (events || []).slice().sort((a, b) => a.event_occurred_at.localeCompare(b.event_occurred_at));
  const ins = ev.filter((e) => e.event_type === "clock_in");
  const outs = ev.filter((e) => e.event_type === "clock_out");
  let pauses = 0, debutPause: string | null = null, nbPauses = 0;
  for (const e of ev) {
    if (e.event_type === "break_start") debutPause = e.event_occurred_at;
    if (e.event_type === "break_end" && debutPause) {
      pauses += minutesEntre(debutPause, e.event_occurred_at) || 0;
      debutPause = null; nbPauses++;
    }
  }
  return {
    debut: ins.length ? ins[0].event_occurred_at : null,
    fin: outs.length ? outs[outs.length - 1].event_occurred_at : null,
    pauses: nbPauses ? pauses : null,
  };
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const start = url.searchParams.get("start") || parisDate(-2);
  const end = url.searchParams.get("end") || parisDate(0); // exclue -> J-2 et J-1
  const summary = { start, end, shifts: {} as Record<string, number>, erreurs: [] as string[] };
  try {
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Rattachement aux comptes PBT : mapping explicite puis nom normalise
    const [{ data: mapping }, { data: users }] = await Promise.all([
      supabase.from("combo_user_mapping").select("combo_collaborateur_nom, user_id"),
      supabase.from("users").select("id, nom"),
    ]);
    const userByName = new Map<string, string>();
    (users || []).forEach((u) => userByName.set(normName(u.nom || ""), u.id));
    (mapping || []).forEach((m) => { if (m.user_id) userByName.set(normName(m.combo_collaborateur_nom || ""), m.user_id); });

    const locations = (await comboGet("/api/v1/locations")) as Array<{ id: string; name: string }>;
    for (const loc of locations) {
      const etab = mapEtab(loc.name);
      if (!etab) continue;
      try {
        const shifts = (await comboGet(
          `/api/v1/plannings?start_date=${start}&end_date=${end}&location_id=${encodeURIComponent(loc.id)}`,
        )) as ComboShift[];

        const rows = [];
        for (const s of shifts) {
          const nom = `${s.firstname || ""} ${s.lastname || ""}`.trim();
          if (!nom || !s.date || !s.starts_at) continue;
          const b = lireBadgeages(s.events);
          rows.push({
            date_service: s.date,
            etablissement_combo: loc.name,
            etablissement: etab,
            equipe_combo: s.team_name,
            equipe: mapEquipe(s.team_name),
            collaborateur_nom_combo: nom,
            user_id: userByName.get(normName(nom)) || null,
            debut_planifie: s.starts_at,
            fin_planifiee: s.ends_at,
            pauses_planifiees_minutes: s.break_duration ?? 0,
            debut_pointe: b.debut,
            fin_pointee: b.fin,
            pauses_pointees_minutes: b.pauses,
            debut_valide: s.real_starts_at,
            fin_validee: s.real_ends_at,
            pauses_validees_minutes: s.real_break_duration,
            // duree_travail_minutes : colonne GENEREE par la base (reel - pauses retenues)
            import_fichier_nom: SOURCE,
            import_date_traitement: new Date().toISOString(),
          });
        }

        // Remplacement idempotent de la periode pour cet etablissement (lignes API seulement)
        const { error: dErr } = await supabase.from("combo_pointages").delete()
          .eq("etablissement", etab).eq("import_fichier_nom", SOURCE)
          .gte("date_service", start).lt("date_service", end);
        if (dErr) throw dErr;
        if (rows.length > 0) {
          const { error: iErr } = await supabase.from("combo_pointages").insert(rows);
          if (iErr) throw iErr;
        }
        summary.shifts[etab] = rows.length;
      } catch (pErr) {
        summary.erreurs.push(`${etab}: ${String((pErr as Error)?.message || pErr)}`);
      }
    }
    return new Response(JSON.stringify(summary), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    summary.erreurs.push(String((err as Error)?.message || err));
    return new Response(JSON.stringify(summary), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
