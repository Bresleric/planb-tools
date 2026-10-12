// ============================================================================
// L Addition Live -> PlanB Tools : CA et stock caisse en direct (12/10/2026)
// Lance par pg_cron toutes les 30 min (job 'laddition-live-30min').
// Source : https://live.laddition.com/api/data (l appli web "L addition live").
// Pas d API officielle : on utilise le jeton de session du compte d Eric.
//   - refreshToken : colle par Eric dans pbt_private.config (cle
//     'laddition_refresh_token') via SQL Editor. Jamais dans le code.
//   - accessToken  : obtenu avec le refreshToken, mis en cache dans
//     pbt_private.config, renouvele seulement si L Addition le refuse.
// Ecrit :
//   - laddition_live         : etat courant par etablissement (1 ligne / etab)
//   - laddition_ventes_jour  : totaux + ventes produits du jour (historique)
//   - laddition_ruptures     : heure a laquelle un article tombe a 0
// En cas d echec, l erreur est notee dans laddition_live (Pilotage l affiche).
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const BASE = "https://live.laddition.com";
const PARIS = "Europe/Paris";
const NON_SUIVI = 1000; // au-dela, le compteur de stock caisse tourne a vide (cafes, eaux...)

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

// Recupere les cookies poses par une reponse (ex. refreshToken renouvele)
function cookiesDe(r: Response): Record<string, string> {
  const out: Record<string, string> = {};
  const liste = (r.headers as any).getSetCookie ? (r.headers as any).getSetCookie() : [];
  for (const c of liste) {
    const [kv] = String(c).split(";");
    const i = kv.indexOf("=");
    if (i > 0) out[kv.slice(0, i).trim()] = kv.slice(i + 1).trim();
  }
  return out;
}

async function nouveauAccessToken(): Promise<string> {
  const refresh = (await cfgGet("laddition_refresh_token")) || Deno.env.get("LADDITION_REFRESH_TOKEN");
  if (!refresh) throw new Error("jeton L Addition absent : coller le refreshToken (voir scripts/migration-laddition-live.sql)");
  let cookie = `refreshToken=${refresh}`;
  let r = await fetch(`${BASE}/api/auth/accessToken`, { headers: { Cookie: cookie } });
  if (r.status === 401) {
    // Meme chemin que le navigateur : la page d accueil recoit le refreshToken en parametre
    const p = await fetch(`${BASE}/?refreshToken=${encodeURIComponent(refresh)}`, { redirect: "manual" });
    const c = cookiesDe(p);
    await p.body?.cancel();
    cookie = Object.entries({ refreshToken: refresh, ...c }).map(([k, v]) => `${k}=${v}`).join("; ");
    r = await fetch(`${BASE}/api/auth/accessToken`, { headers: { Cookie: cookie } });
  }
  const nouveau = cookiesDe(r).refreshToken;
  if (nouveau && nouveau !== refresh) await cfgSet("laddition_refresh_token", nouveau);
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.accessToken) throw new Error(`L Addition refuse la connexion (HTTP ${r.status}) : jeton a renouveler`);
  await cfgSet("laddition_access_token", j.accessToken);
  return j.accessToken;
}

async function lireData(): Promise<any> {
  let token = await cfgGet("laddition_access_token");
  for (let essai = 0; essai < 2; essai++) {
    if (!token) token = await nouveauAccessToken();
    const r = await fetch(`${BASE}/api/data`, { headers: { Authorization: `Bearer ${token}` } });
    if (r.status === 401 || r.status === 403) { await r.body?.cancel(); token = null; continue; }
    const j = await r.json().catch(() => null);
    if (!r.ok || !j || j.ok !== true) throw new Error(`api/data -> HTTP ${r.status}`);
    return j;
  }
  throw new Error("L Addition refuse le jeton apres renouvellement");
}

function etabDe(company: string): string | null {
  const c = (company || "").toLowerCase();
  if (c.includes("freddy")) return "freddy";
  if (c.includes("liesel")) return "liesel";
  return null;
}
const iso = (s: number) => (s ? new Date(s * 1000).toISOString() : null);
const dateParis = (s: number) => new Intl.DateTimeFormat("fr-CA", { timeZone: PARIS }).format(new Date(s * 1000));
const r2 = (v: unknown) => Math.round((Number(v) || 0) * 100) / 100;
const lignesVentes = (arr: any[], cle = "product_name") =>
  (arr || []).map((p) => ({ nom: String(p[cle] || "").trim(), qte: r2(p.quantity), ca: r2(p.value) }));
// Certains articles existent en double dans la caisse (ex. 2 "Creme brulee") et leur
// ordre change d une photo a l autre : cle = "nom #2"... pour l affichage, et
// "doublon" = true pour ne calculer ni ecart ni rupture dessus (impossible a suivre).
const stocksDe = (d: any) => {
  const liste = (d.stocks || []).flat().map((s: any) => ({ nom: String(s.name || "").replace(/\s+/g, " ").trim(), qte: r2(s.quantity) }));
  const total = new Map<string, number>();
  liste.forEach((s: any) => total.set(s.nom, (total.get(s.nom) || 0) + 1));
  const vus = new Map<string, number>();
  return liste.map((s: any) => {
    const k = (vus.get(s.nom) || 0) + 1;
    vus.set(s.nom, k);
    return { ...s, cle: k > 1 ? `${s.nom} #${k}` : s.nom, doublon: (total.get(s.nom) || 0) > 1 };
  });
};

Deno.serve(async (_req) => {
  const resume = { etabs: [] as string[], ruptures: 0, erreurs: [] as string[] };
  const maintenant = new Date().toISOString();
  try {
    const j = await lireData();
    const comptes: any[] = j.compte?.linked?.length ? j.compte.linked : [j.compte];

    for (const compte of comptes) {
      const etab = etabDe(compte.company);
      const snaps: any[] = (j.data || {})[compte.email] || [];
      if (!etab) continue;
      if (!snaps.length) {
        // Pas de service ouvert : on garde les dernieres donnees, on note juste le passage
        await supa.from("laddition_live").upsert({ etablissement: etab, synchro_le: maintenant, erreur: null }, { onConflict: "etablissement" });
        resume.etabs.push(`${etab}: aucun service ouvert`);
        continue;
      }
      // Chaque photo contient le total du restaurant (meme avec plusieurs iPads) :
      // la plus recente fait foi.
      snaps.sort((a, b) => (a.update_ || 0) - (b.update_ || 0));
      const parsed = snaps.map((s) => ({ s, d: JSON.parse(s.data || "{}") }));
      const { s: last, d } = parsed[parsed.length - 1];
      const ouverture = Math.min(...snaps.map((s) => s.opening_date || Infinity));
      const dateService = dateParis(ouverture);

      // Stock : quantite a la premiere photo du service vs maintenant
      const stockOuv = new Map<string, number>();
      for (const s of stocksDe(parsed[0].d)) if (!s.doublon) stockOuv.set(s.cle, s.qte);
      const stocks = stocksDe(d).map((s: any) => ({ nom: s.nom, cle: s.cle, qte: s.qte, qte_ouv: !s.doublon && stockOuv.has(s.cle) ? stockOuv.get(s.cle) : null }));

      // Ruptures : premiere photo ou un article suivi passe de >0 a <=0
      const ruptures = new Map<string, number>();
      let prec = new Map<string, number>();
      for (const { s, d: dd } of parsed) {
        for (const st of stocksDe(dd)) {
          if (st.doublon) continue;
          const avant = prec.get(st.cle);
          if (avant !== undefined && avant > 0 && avant < NON_SUIVI && st.qte <= 0 && !ruptures.has(st.cle)) ruptures.set(st.cle, s.update_);
        }
        prec = new Map(stocksDe(dd).map((x: any) => [x.cle, x.qte]));
      }

      const serveurs = Object.values(d.users || {}).map((u: any) => ({
        nom: [u.firstname, u.lastname].filter(Boolean).join(" ").replace(/\s+/g, " ").trim() || "?",
        ca: r2(u.turnover), couverts: u.nb_guests || 0, additions: u.nb || 0, remise: r2(u.discount), offert: r2(u.offered),
      }));
      const salles = Object.values(d.floors || {}).map((f: any) => ({ nom: String(f.name || "").trim(), ca: r2(f.ca), remise: r2(f.discount) }));
      const produits = lignesVentes(d.products);
      const ligne = {
        etablissement: etab,
        date_service: dateService,
        service_ouvert: iso(ouverture),
        maj_caisse: iso(last.update_),
        synchro_le: maintenant,
        ca: r2(last.turnover),
        encaisse: r2(last.cashed),
        remise: r2(last.discount),
        offert: r2(last.offered),
        couverts: last.nb_guests || 0,
        additions: serveurs.reduce((t, u) => t + u.additions, 0),
        moyenne_couvert: r2(last.guest_average),
        ticket_moyen: r2(last.order_average),
        annulations: d.cancel || null,
        serveurs, salles, produits,
        options: lignesVentes(d.modifiers, "modifier_name"),
        menus: lignesVentes(d.menus),
        stocks,
        evolution: snaps.map((s) => ({ t: iso(s.update_), ca: r2(s.turnover), enc: r2(s.cashed) })),
        erreur: null,
      };
      const { error: e1 } = await supa.from("laddition_live").upsert(ligne, { onConflict: "etablissement" });
      if (e1) throw new Error("laddition_live: " + e1.message);

      const { error: e2 } = await supa.from("laddition_ventes_jour").upsert({
        etablissement: etab, date_service: dateService, ca: ligne.ca, encaisse: ligne.encaisse,
        couverts: ligne.couverts, additions: ligne.additions, remise: ligne.remise, offert: ligne.offert,
        produits, menus: ligne.menus, maj_le: maintenant,
      }, { onConflict: "etablissement,date_service" });
      if (e2) throw new Error("laddition_ventes_jour: " + e2.message);

      if (ruptures.size) {
        const lignesR = [...ruptures].map(([produit, t]) => ({ etablissement: etab, date_service: dateService, produit, epuise_vers: iso(t) }));
        const { error: e3 } = await supa.from("laddition_ruptures").upsert(lignesR, { onConflict: "etablissement,date_service,produit", ignoreDuplicates: true });
        if (e3) throw new Error("laddition_ruptures: " + e3.message);
        resume.ruptures += lignesR.length;
      }
      resume.etabs.push(`${etab}: CA ${ligne.ca} / ${ligne.couverts} couv. (${snaps.length} photos)`);
    }
    return new Response(JSON.stringify(resume), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    const msg = String((e as Error)?.message || e);
    resume.erreurs.push(msg);
    await supa.from("laddition_live").upsert(
      [{ etablissement: "freddy", erreur: msg, erreur_le: maintenant }, { etablissement: "liesel", erreur: msg, erreur_le: maintenant }],
      { onConflict: "etablissement" },
    );
    return new Response(JSON.stringify(resume), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
