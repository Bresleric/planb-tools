// ============================================================================
// Veilleur Combo — nouveaux collaborateurs + synchronisation des plannings
// ----------------------------------------------------------------------------
// Lance par pg_cron (2 fois par jour) :
//   A. NOUVEAUX COLLABORATEURS
//      - interroge l API Combo (locations puis contrats actifs du jour)
//      - compare aux utilisateurs PlanB-Tools (nom normalise, mots tries)
//      - cree les manquants (role collaborateur, PIN genere) + journal
//   B. PLANNINGS (forces en presence)
//      - recupere les shifts Combo du jour et du lendemain
//      - remplace les lignes correspondantes de planning_equipes
//      - consommes par le Briefing (section Equipes) et le TAF (assignation)
// Minimisation : prenom/nom, etablissement, equipe et horaires uniquement.
// Aucune donnee RH sensible (NIR, adresse, salaire) ne quitte les appels.
// Secrets requis (Edge Functions -> Secrets) : COMBO_API_KEY
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const COMBO_BASE = "https://partner.combohr.com";
const PARIS = "Europe/Paris";

function normName(s: string): string {
  // Minuscules sans accents, puis mots tries par ordre alphabetique :
  // "BRESLER Eric" et "Eric Bresler" donnent la meme cle (Combo inverse parfois)
  return s.trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .split(/\s+/).sort().join(" ");
}

function makeInitiales(firstname: string, lastname: string): string {
  return ((firstname[0] || "") + (lastname[0] || "")).toUpperCase();
}

function genPin(taken: Set<string>): string {
  for (let i = 0; i < 200; i++) {
    const pin = String(Math.floor(1000 + Math.random() * 9000));
    if (!taken.has(pin)) { taken.add(pin); return pin; }
  }
  throw new Error("Impossible de generer un PIN libre");
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

function parisDate(offsetDays = 0): string {
  const d = new Date(Date.now() + offsetDays * 86400000);
  return new Intl.DateTimeFormat("fr-CA", { timeZone: PARIS }).format(d); // YYYY-MM-DD
}

function toHM(ts: string | null): string | null {
  if (!ts) return null;
  // Horodatage avec fuseau -> conversion Paris ; heure locale nue -> extraction directe
  if (/(Z|[+-]\d{2}:?\d{2})$/.test(ts)) {
    const d = new Date(ts);
    if (isNaN(d.getTime())) return null;
    return new Intl.DateTimeFormat("fr-FR", { timeZone: PARIS, hour: "2-digit", minute: "2-digit", hour12: false }).format(d).replace("h", ":");
  }
  const m = ts.match(/T?(\d{2}:\d{2})/g);
  return m ? m[m.length - 1].replace("T", "") : null;
}

function classifyService(debut: string, fin: string): string {
  const sh = parseInt(debut.slice(0, 2), 10);
  const eh = parseInt(fin.slice(0, 2), 10);
  if (eh < sh) return "soir";                 // passe minuit
  if (sh < 15 && eh >= 19) return "journee";  // couvre les deux services
  if (eh <= 18) return "midi";
  return "soir";
}

async function comboGet(path: string): Promise<unknown> {
  const res = await fetch(COMBO_BASE + path, {
    headers: { Authorization: `Bearer ${Deno.env.get("COMBO_API_KEY")}` },
  });
  if (!res.ok) throw new Error(`Combo ${path} -> HTTP ${res.status}`);
  return await res.json();
}

Deno.serve(async (_req) => {
  const summary = {
    locations: 0, salaries_vus: 0, deja_connus: 0,
    crees: [] as string[], a_verifier: [] as string[],
    plannings: {} as Record<string, number>,
    erreurs: [] as string[],
  };
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: users, error: uErr } = await supabase.from("users").select("nom, code");
    if (uErr) throw uErr;
    const knownNames = new Set((users || []).map((u) => normName(u.nom || "")));
    const takenPins = new Set((users || []).map((u) => String(u.code || "")));

    const locations = (await comboGet("/api/v1/locations")) as Array<{ id: string; name: string }>;
    summary.locations = locations.length;

    const today = parisDate(0);
    const tomorrow = parisDate(1);
    // L API Combo EXCLUT end_date : pour avoir aujourd hui ET demain, on demande
    // jusqu a apres-demain (constat du 04/10/2026, le planning du lendemain manquait)
    const apresDemain = parisDate(2);

    const seen = new Set<string>();
    for (const loc of locations) {
      const etab = mapEtab(loc.name);

      // ---------- A. Nouveaux collaborateurs ----------
      const contracts = (await comboGet(`/api/v1/contracts?location_id=${encodeURIComponent(loc.id)}`)) as Array<{ firstname: string | null; lastname: string | null }>;
      for (const c of contracts) {
        const fullname = `${c.firstname || ""} ${c.lastname || ""}`.trim();
        if (!fullname) continue;
        const key = normName(fullname);
        if (seen.has(key)) continue;
        seen.add(key);
        summary.salaries_vus++;

        if (knownNames.has(key)) { summary.deja_connus++; continue; }

        if (!etab) {
          await supabase.from("combo_veilleur_log").insert({
            nom: fullname, etablissement: null, statut: "a_verifier",
            detail: `Etablissement Combo non reconnu : ${loc.name}`,
          });
          summary.a_verifier.push(fullname);
          continue;
        }

        const pin = genPin(takenPins);
        const { data: created, error: cErr } = await supabase.from("users").insert({
          nom: fullname,
          initiales: makeInitiales(c.firstname || "", c.lastname || ""),
          code: pin,
          role: "collaborateur",
          etablissement: etab,
          acces_etablissements: [etab],
          actif: true,
        }).select("id");
        if (cErr) { summary.erreurs.push(`${fullname}: ${cErr.message}`); continue; }
        knownNames.add(key);
        await supabase.from("combo_veilleur_log").insert({
          nom: fullname, etablissement: etab, statut: "cree",
          user_id: created?.[0]?.id || null, pin: pin,
          detail: `Cree depuis Combo (${loc.name})`,
        });
        summary.crees.push(`${fullname} (${etab})`);
      }

      // ---------- B. Plannings (forces en presence) ----------
      if (!etab) continue;
      try {
        const shifts = (await comboGet(
          `/api/v1/plannings?start_date=${today}&end_date=${apresDemain}&location_id=${encodeURIComponent(loc.id)}`,
        )) as Array<{
          date: string; starts_at: string | null; ends_at: string | null;
          break_duration: number | null; note: string | null;
          firstname: string | null; lastname: string | null; team_name: string | null;
        }>;

        const rows = [];
        for (const s of shifts) {
          const nom = `${s.firstname || ""} ${s.lastname || ""}`.trim();
          const debut = toHM(s.starts_at);
          const fin = toHM(s.ends_at);
          if (!nom || !debut || !fin || !s.date) continue;
          rows.push({
            date: s.date,
            etablissement: etab,
            employe_nom: nom,
            employe_initiales: makeInitiales(s.firstname || "", s.lastname || ""),
            equipe: mapEquipe(s.team_name),
            poste: s.note || s.team_name || "",
            heure_debut: debut,
            heure_fin: fin,
            service: classifyService(debut, fin),
            notes: s.break_duration ? `pause ${s.break_duration}mn` : "",
          });
        }

        // Remplacement idempotent des deux journees pour cet etablissement
        const { error: dErr } = await supabase.from("planning_equipes")
          .delete().eq("etablissement", etab).in("date", [today, tomorrow]);
        if (dErr) throw dErr;
        if (rows.length > 0) {
          const { error: iErr } = await supabase.from("planning_equipes").insert(rows);
          if (iErr) throw iErr;
        }
        summary.plannings[etab] = rows.length;
      } catch (pErr) {
        summary.erreurs.push(`planning ${etab}: ${String(pErr?.message || pErr)}`);
      }
    }

    return new Response(JSON.stringify(summary), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    summary.erreurs.push(String(err?.message || err));
    return new Response(JSON.stringify(summary), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
