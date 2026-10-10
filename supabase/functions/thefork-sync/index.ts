// ============================================================================
// TheFork -> PlanB Tools : synchronisation des reservations (10/10/2026)
// Lance par pg_cron toutes les heures. Fenetre J -> J+14, filterBy=mealDate.
// - Jeton OAuth2 mis en CACHE (pbt_private.config via RPC service) : TheFork
//   demande de NE PAS redemander un jeton tant que le precedent est valide
//   (expiration ~8600 s ; renouvellement 5 min avant).
// - Minimisation des donnees clients : nom + allergies + commentaire.
//   Ni telephone ni email.
// Secrets requis : THEFORK_CLIENT_ID, THEFORK_CLIENT_SECRET.
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const PARIS = "Europe/Paris";
const RESTAURANTS = [
  { uuid: "bc0ba9e6-c38b-451d-9c24-72a226ee13c6", etablissement: "freddy" },
  // Liesel : ajouter ici son uuid TheFork le jour venu
];

const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

async function cfgGet(cle: string): Promise<string | null> {
  const { data, error } = await supa.rpc("pbt_service_config_get", { p_cle: cle });
  if (error) throw new Error("config_get: " + error.message);
  return data ?? null;
}
async function cfgSet(cle: string, valeur: string) {
  const { error } = await supa.rpc("pbt_service_config_set", { p_cle: cle, p_valeur: valeur });
  if (error) throw new Error("config_set: " + error.message);
}

async function getToken(): Promise<string> {
  const [tok, exp] = await Promise.all([cfgGet("thefork_token"), cfgGet("thefork_token_exp")]);
  if (tok && exp && Date.now() < Number(exp)) return tok;
  const cid = Deno.env.get("THEFORK_CLIENT_ID");
  const sec = Deno.env.get("THEFORK_CLIENT_SECRET");
  if (!cid || !sec) throw new Error("secrets THEFORK_* absents");
  const tr = await fetch("https://auth.thefork.io/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ grant_type: "client_credentials", client_id: cid, client_secret: sec, audience: "https://api.thefork.io" }),
  });
  const tj = await tr.json().catch(() => ({}));
  if (!tr.ok || !tj.access_token) throw new Error(`jeton TheFork refuse (HTTP ${tr.status})`);
  const dureeS = Number(tj.expires_in) > 0 ? Number(tj.expires_in) : 8600;
  await cfgSet("thefork_token", tj.access_token);
  await cfgSet("thefork_token_exp", String(Date.now() + (dureeS - 300) * 1000));
  return tj.access_token;
}

async function tfGet(token: string, chemin: string): Promise<any> {
  const r = await fetch("https://api.thefork.io/manager" + chemin, { headers: { Authorization: `Bearer ${token}` } });
  if (!r.ok) throw new Error(`TheFork ${chemin.split("?")[0]} -> HTTP ${r.status}`);
  return await r.json();
}

function parisDate(offsetDays = 0): string {
  return new Intl.DateTimeFormat("fr-CA", { timeZone: PARIS }).format(new Date(Date.now() + offsetDays * 86400000));
}
function parisDateHeure(iso: string): { date: string; heure: string } {
  const d = new Date(iso);
  const date = new Intl.DateTimeFormat("fr-CA", { timeZone: PARIS }).format(d);
  const heure = new Intl.DateTimeFormat("fr-FR", { timeZone: PARIS, hour: "2-digit", minute: "2-digit", hour12: false }).format(d).replace("h", ":");
  return { date, heure };
}

function texte(v: unknown): string | null {
  if (v == null) return null;
  if (Array.isArray(v)) return v.filter(Boolean).join(", ") || null;
  const s = String(v).trim();
  return s || null;
}

Deno.serve(async (_req) => {
  const resume = { fenetres: [] as string[], reservations: 0, upserts: 0, erreurs: [] as string[] };
  try {
    const token = await getToken();
    const debut = parisDate(0);
    const fin = parisDate(14);
    const clientsCache = new Map<string, any>();

    for (const resto of RESTAURANTS) {
      resume.fenetres.push(`${resto.etablissement} ${debut}->${fin}`);
      const liste = await tfGet(token, `/v1/reservations?restaurantUuid=${resto.uuid}&startDate=${debut}&endDate=${fin}&filterBy=mealDate&limit=1000`);
      const ids: string[] = liste.data || [];
      resume.reservations += ids.length;
      const lignes = [];
      for (const id of ids) {
        try {
          const r = await tfGet(token, `/v1/reservations/${id}`);
          let client: any = null;
          if (r.customerUuid) {
            if (!clientsCache.has(r.customerUuid)) {
              try { clientsCache.set(r.customerUuid, await tfGet(token, `/v1/customers/${r.customerUuid}`)); }
              catch (_) { clientsCache.set(r.customerUuid, null); }
            }
            client = clientsCache.get(r.customerUuid);
          }
          const dh = parisDateHeure(r.mealDate);
          const heureNum = parseInt(dh.heure.slice(0, 2), 10);
          const allergies = [texte(client?.allergiesAndIntolerances), texte(client?.dietaryRestrictions)].filter(Boolean).join(" · ") || null;
          const commentaire = [texte(r.customerNote), texte(r.restaurantNote) ? "Resto : " + texte(r.restaurantNote) : null].filter(Boolean).join(" · ") || null;
          lignes.push({
            thefork_id: r.reservationUuid,
            etablissement: resto.etablissement,
            date: dh.date,
            heure: dh.heure,
            service: heureNum < 16 ? "midi" : "soir",
            couverts: r.partySize ?? null,
            statut: r.status || null,
            nom_client: texte([client?.firstName, client?.lastName].filter(Boolean).join(" ")),
            allergies,
            commentaire,
            payload: r,
            updated_at: new Date().toISOString(),
          });
        } catch (e) { resume.erreurs.push(`${id}: ${String((e as Error)?.message || e)}`); }
      }
      if (lignes.length) {
        const { error } = await supa.from("reservations_thefork").upsert(lignes, { onConflict: "thefork_id" });
        if (error) throw new Error("upsert: " + error.message);
        resume.upserts += lignes.length;
      }
    }
    return new Response(JSON.stringify(resume), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    resume.erreurs.push(String((e as Error)?.message || e));
    return new Response(JSON.stringify(resume), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
