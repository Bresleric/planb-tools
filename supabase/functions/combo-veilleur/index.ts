// ============================================================================
// Veilleur Combo — detection des nouveaux collaborateurs
// ----------------------------------------------------------------------------
// Chaque nuit (pg_cron -> net.http_post), cette fonction :
//   1. interroge l API Combo (locations puis contrats actifs du jour)
//   2. compare les salaries aux utilisateurs PlanB-Tools (match par nom complet)
//   3. cree les manquants (role collaborateur, PIN genere, bon etablissement)
//   4. journalise tout dans combo_veilleur_log (lu par le rapport journalier)
// Principe de minimisation : on ne lit que prenom/nom + etablissement.
// Aucune autre donnee RH de Combo (NIR, adresse, salaire) ne quitte l appel.
// Secrets requis (Edge Functions -> Secrets) : COMBO_API_KEY
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const COMBO_BASE = "https://partner.combohr.com";

function normName(s: string): string {
  // Minuscules sans accents, puis mots tries par ordre alphabetique :
  // "BRESLER Eric" et "Eric Bresler" donnent la meme cle (Combo inverse parfois)
  return s.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
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
  const n = normName(locationName);
  if (n.includes("freddy")) return "freddy";
  if (n.includes("liesel")) return "liesel";
  return null;
}

async function comboGet(path: string): Promise<unknown> {
  const res = await fetch(COMBO_BASE + path, {
    headers: { Authorization: `Bearer ${Deno.env.get("COMBO_API_KEY")}` },
  });
  if (!res.ok) throw new Error(`Combo ${path} -> HTTP ${res.status}`);
  return await res.json();
}

Deno.serve(async (_req) => {
  const summary = { locations: 0, salaries_vus: 0, deja_connus: 0, crees: [] as string[], a_verifier: [] as string[], erreurs: [] as string[] };
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Utilisateurs existants (comparaison par nom normalise) + PINs pris
    const { data: users, error: uErr } = await supabase.from("users").select("nom, code");
    if (uErr) throw uErr;
    const knownNames = new Set((users || []).map((u) => normName(u.nom || "")));
    const takenPins = new Set((users || []).map((u) => String(u.code || "")));

    const locations = (await comboGet("/api/v1/locations")) as Array<{ id: string; name: string }>;
    summary.locations = locations.length;

    const seen = new Set<string>(); // dedupe salaries presents dans plusieurs contrats/avenants
    for (const loc of locations) {
      const etab = mapEtab(loc.name);
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
          // Etablissement Combo inconnu : on journalise sans creer, decision humaine
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
        if (cErr) {
          summary.erreurs.push(`${fullname}: ${cErr.message}`);
          continue;
        }
        knownNames.add(key);
        await supabase.from("combo_veilleur_log").insert({
          nom: fullname, etablissement: etab, statut: "cree",
          user_id: created?.[0]?.id || null, pin: pin,
          detail: `Cree depuis Combo (${loc.name})`,
        });
        summary.crees.push(`${fullname} (${etab})`);
      }
    }

    return new Response(JSON.stringify(summary), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    summary.erreurs.push(String(err?.message || err));
    return new Response(JSON.stringify(summary), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
