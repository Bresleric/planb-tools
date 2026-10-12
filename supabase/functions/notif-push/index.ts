// ============================================================================
// notif-push : notifications Web Push vers les iPads + copie Telegram (12/10/2026)
// Lance par pg_cron toutes les 5 min (action "tick") et appele par le portail
// (cle_publique, test) et par le service worker (renouveler).
//
// Actions :
//   - cle_publique : renvoie la cle VAPID publique (le front en a besoin
//     pour s abonner ; elle est publique par nature)
//   - test {endpoint} : envoie une notification de test a CET appareil seulement
//   - renouveler {ancien_endpoint, abonnement} : Apple a fait tourner un
//     abonnement, on remplace l endpoint en base (appele par sw.js)
//   - tick (defaut) : rpc notif_evenements() -> anti-doublon / relance ->
//     push vers les iPads de la maison -> 404/410 = abonnement revoque ->
//     journal notifications_envoyees -> UN message Telegram groupe par tick
//
// Secrets : VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (mailto:...),
// TELEGRAM_BOT_TOKEN (existant). Le chat admin vit dans telegram_config.
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY") || "";
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY") || "";
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") || "mailto:bresleric@planbcie.com";
if (VAPID_PUBLIC && VAPID_PRIVATE) webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

// CORS : le portail (bresleric.github.io) appelle cette fonction depuis le
// navigateur (cle_publique, test). Sans ces en-tetes, Safari bloque l appel
// avec un simple "Load failed".
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json", ...CORS } });

type Abo = { id: number; endpoint: string; p256dh: string; auth: string; etablissement: string | null };

async function envoyer(abo: Abo, payload: Record<string, unknown>): Promise<"ok" | "revoque" | "echec"> {
  try {
    await webpush.sendNotification(
      { endpoint: abo.endpoint, keys: { p256dh: abo.p256dh, auth: abo.auth } },
      JSON.stringify(payload),
      { TTL: 3600 },
    );
    return "ok";
  } catch (e) {
    const code = (e as { statusCode?: number })?.statusCode;
    if (code === 404 || code === 410) {
      await supa.from("push_subscriptions").update({ revoked_at: new Date().toISOString() }).eq("id", abo.id);
      return "revoque";
    }
    console.warn("push echec", code); // jamais l endpoint complet dans les logs
    return "echec";
  }
}

async function telegramAdmin(texte: string) {
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  if (!botToken) return;
  const { data } = await supa.from("telegram_config").select("valeur").eq("cle", "chat_id_admin").maybeSingle();
  if (!data?.valeur) return;
  await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: data.valeur, text: texte }),
  }).catch(() => {});
}

async function abonnementsActifs(etab?: string): Promise<Abo[]> {
  let q = supa.from("push_subscriptions").select("id, endpoint, p256dh, auth, etablissement").is("revoked_at", null);
  if (etab) q = q.eq("etablissement", etab);
  const { data, error } = await q;
  if (error) throw new Error("push_subscriptions: " + error.message);
  return (data || []) as Abo[];
}

async function tick() {
  const resume = { evenements: 0, envoyes: 0, relances: 0, ignores: 0, pushs: 0, revoques: 0, telegram: false, erreurs: [] as string[] };
  const { data: evts, error } = await supa.rpc("notif_evenements");
  if (error) throw new Error("notif_evenements: " + error.message);
  if (!evts?.length) return resume;
  resume.evenements = evts.length;

  const { data: regles, error: eR } = await supa.from("notification_regles").select("*");
  if (eR) throw new Error("notification_regles: " + eR.message);
  const regleDe = new Map((regles || []).map((r: any) => [r.code, r]));
  const lignesTelegram: string[] = [];

  for (const ev of evts) {
    const regle = regleDe.get(ev.regle_code);
    if (!regle) continue;
    // Anti-doublon / relance
    const { data: deja } = await supa.from("notifications_envoyees").select("id, dernier_envoi_at, nb_envois")
      .eq("regle_code", ev.regle_code).eq("etablissement", ev.etablissement).eq("cle", ev.cle).maybeSingle();
    let relance = false;
    if (deja) {
      if (!regle.relance_minutes) { resume.ignores++; continue; }
      const age = Date.now() - new Date(deja.dernier_envoi_at).getTime();
      if (age < regle.relance_minutes * 60000) { resume.ignores++; continue; }
      relance = true;
    }

    // Push vers les iPads de la maison concernee
    let nbAppareils = 0;
    if (regle.tablettes) {
      const abos = await abonnementsActifs(ev.etablissement);
      nbAppareils = abos.length;
      const payload = { title: ev.titre, body: ev.corps, url: ev.url || "./", tag: `${ev.regle_code}-${ev.cle}` };
      for (const abo of abos) {
        const res = await envoyer(abo, payload);
        if (res === "ok") resume.pushs++;
        else if (res === "revoque") resume.revoques++;
      }
    }
    if (regle.telegram) {
      const maison = ev.etablissement === "freddy" ? "Freddy" : "Liesel";
      lignesTelegram.push(`${relance ? "(relance) " : ""}[${maison}] ${ev.titre} : ${ev.corps}`);
    }

    // Journal
    const maintenant = new Date().toISOString();
    if (deja) {
      await supa.from("notifications_envoyees").update({
        titre: ev.titre, corps: ev.corps, nb_appareils: nbAppareils,
        nb_envois: (deja.nb_envois || 1) + 1, dernier_envoi_at: maintenant, telegram: !!regle.telegram,
      }).eq("id", deja.id);
      resume.relances++;
    } else {
      const { error: eJ } = await supa.from("notifications_envoyees").insert({
        regle_code: ev.regle_code, etablissement: ev.etablissement, cle: ev.cle,
        titre: ev.titre, corps: ev.corps, nb_appareils: nbAppareils, telegram: !!regle.telegram,
      });
      if (eJ) resume.erreurs.push("journal: " + eJ.message);
      resume.envoyes++;
    }
  }

  if (lignesTelegram.length) {
    await telegramAdmin("🔔 PlanB Tools\n" + lignesTelegram.join("\n"));
    resume.telegram = true;
  }
  return resume;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  let body: any = {};
  try { body = await req.json(); } catch (_) { /* tick par defaut */ }
  const action = body.action || "tick";
  try {
    if (action === "cle_publique") {
      if (!VAPID_PUBLIC) return json({ erreur: "cle VAPID absente des secrets" }, 500);
      return json({ cle: VAPID_PUBLIC });
    }
    if (action === "test") {
      if (!body.endpoint) return json({ erreur: "endpoint manquant" }, 400);
      const abos = (await abonnementsActifs()).filter((a) => a.endpoint === body.endpoint);
      if (!abos.length) return json({ erreur: "abonnement inconnu" }, 404);
      const res = await envoyer(abos[0], {
        title: "PlanB Tools", body: "Les notifications fonctionnent sur cet appareil ✅", url: "./", tag: "test",
      });
      return json({ resultat: res }, res === "ok" ? 200 : 502);
    }
    if (action === "renouveler") {
      const { ancien_endpoint, abonnement } = body;
      const keys = abonnement?.keys || {};
      if (!ancien_endpoint || !abonnement?.endpoint || !keys.p256dh || !keys.auth) return json({ erreur: "parametres manquants" }, 400);
      const { error } = await supa.from("push_subscriptions")
        .update({ endpoint: abonnement.endpoint, p256dh: keys.p256dh, auth: keys.auth, last_seen_at: new Date().toISOString(), revoked_at: null })
        .eq("endpoint", ancien_endpoint);
      if (error) return json({ erreur: error.message }, 500);
      return json({ resultat: "ok" });
    }
    // defaut : tick
    const resume = await tick();
    return json(resume);
  } catch (e) {
    return json({ erreur: String((e as Error)?.message || e) }, 500);
  }
});
