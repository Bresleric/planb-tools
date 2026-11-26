// ============================================================================
// PlanB Tools — Notifications Telegram administrateur (05/10/2026)
//
// Actions (POST JSON { action, ... }) :
//  - whoami   : liste les chats vus par le bot (getUpdates). Autorise UNIQUEMENT
//               tant qu aucun chat admin n est enregistre (phase de setup).
//  - register : { chat_id } enregistre le chat admin. Premier arrive = verrouille
//               (le repo etant public, on empeche un detournement via la cle anon).
//  - test     : envoie un message de test au chat enregistre.
//  - digest   : recapitule les nouveaux besoins appro + demandes entre maisons
//               depuis le dernier digest. Appele par pg_cron (toutes les 30 min).
//
// Secrets requis : TELEGRAM_BOT_TOKEN (dashboard Supabase > Edge Functions > Secrets)
// Le chat_id et le curseur de digest vivent dans la table telegram_config
// (RLS sans policy anon : accessible uniquement via le service role).
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN') || '';
const supa = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

async function tg(method: string, payload: Record<string, unknown>) {
  const r = await fetch(`https://api.telegram.org/bot${TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return await r.json();
}

async function getCfg(cle: string): Promise<string | null> {
  const { data } = await supa.from('telegram_config').select('valeur').eq('cle', cle).maybeSingle();
  return data?.valeur ?? null;
}
async function setCfg(cle: string, valeur: string) {
  await supa.from('telegram_config').upsert({ cle, valeur, updated_at: new Date().toISOString() });
}

Deno.serve(async (req) => {
  const json = (o: unknown, status = 200) =>
    new Response(JSON.stringify(o), { status, headers: { 'Content-Type': 'application/json' } });

  if (!TOKEN) return json({ error: 'TELEGRAM_BOT_TOKEN manquant : ajouter le secret dans Supabase > Edge Functions > Secrets' }, 500);

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch (_) { /* corps vide tolere */ }
  const action = (body.action as string) || 'digest';

  const chatId = await getCfg('chat_id_admin');

  // --- Setup : decouverte du chat_id (bloquee une fois configure) ---
  if (action === 'whoami') {
    if (chatId) return json({ error: 'deja configure' }, 403);
    const upd = await tg('getUpdates', {});
    const hook = await tg('getWebhookInfo', {});
    const chats = ((upd.result as Array<Record<string, any>>) || [])
      .map((u) => u.message?.chat)
      .filter(Boolean)
      .map((c) => ({ id: c.id, nom: [c.first_name, c.last_name].filter(Boolean).join(' '), username: c.username || null }));
    const seen = new Set<number>();
    const uniq = chats.filter((c) => !seen.has(c.id) && !!seen.add(c.id));
    return json({ ok: upd.ok, chats: uniq, webhook: hook.result?.url || null });
  }

  // --- Setup : enregistrement du chat admin (premier arrive = verrouille) ---
  if (action === 'register') {
    if (!body.chat_id) return json({ error: 'chat_id requis' }, 400);
    if (chatId && String(body.chat_id) !== chatId) return json({ error: 'un chat admin est deja enregistre' }, 403);
    await setCfg('chat_id_admin', String(body.chat_id));
    const res = await tg('sendMessage', {
      chat_id: body.chat_id,
      text: '✅ PlanB Tools est connecté à Telegram.\nTu recevras ici les alertes administrateur (besoins appro, demandes entre maisons).',
    });
    return json({ ok: res.ok === true });
  }

  if (!chatId) return json({ error: 'aucun chat admin enregistre : lancer d abord whoami puis register' }, 400);

  // --- Message de test ---
  if (action === 'test') {
    const res = await tg('sendMessage', { chat_id: chatId, text: (body.text as string) || '🔧 Message de test PlanB Tools' });
    return json({ ok: res.ok === true, telegram: res });
  }

  // --- Rappel jeton L Addition (pg_cron quotidien 'laddition-jeton-rappel') ---
  // Le refreshToken L Addition vit 18 a 19 jours. A partir du 15e jour apres
  // le dernier collage (pbt_private.config.laddition_jeton_colle_le), un rappel
  // par jour maximum, jusqu au renouvellement (qui remet le compteur a zero via
  // pbt_admin_laddition_jeton). Pas de rappel un jour ou l alerte d echec de la
  // synchro (laddition_alerte_le, geree par laddition-live) est deja partie.
  if (action === 'jeton_laddition') {
    const cfg = async (cle: string) => {
      const { data, error } = await supa.rpc('pbt_service_config_get', { p_cle: cle });
      if (error) throw new Error('config_get: ' + error.message);
      return (data as string | null) || '';
    };
    const colle = await cfg('laddition_jeton_colle_le');
    if (!colle) return json({ ok: true, envoye: false, motif: 'date du jeton inconnue' });
    const colleLe = new Date(colle).getTime();
    const ageJours = Math.floor((Date.now() - colleLe) / 86400000);
    if (ageJours < 15) return json({ ok: true, envoye: false, age_jours: ageJours });

    const jourParis = (t: number) => new Intl.DateTimeFormat('fr-CA', { timeZone: 'Europe/Paris' }).format(new Date(t));
    const aujourdhui = jourParis(Date.now());
    const dernierRappel = await cfg('laddition_rappel_jeton_le');
    if (dernierRappel && jourParis(new Date(dernierRappel).getTime()) === aujourdhui) return json({ ok: true, envoye: false, motif: 'deja rappele aujourd hui' });
    const alerteLe = Number(await cfg('laddition_alerte_le')) || 0;
    if (alerteLe && jourParis(alerteLe) === aujourdhui) return json({ ok: true, envoye: false, motif: 'alerte echec deja envoyee aujourd hui' });

    const expire = new Intl.DateTimeFormat('fr-FR', { timeZone: 'Europe/Paris', day: '2-digit', month: '2-digit' }).format(new Date(colleLe + 18 * 86400000));
    const texte = ageJours >= 18
      ? `🔑 Jeton L'Addition probablement expiré (collé il y a ${ageJours} jours, expirait vers le ${expire}).\nPlanB Tools → Admin → onglet L'Addition.`
      : `🔑 Jeton L'Addition à renouveler : expire vers le ${expire} (collé il y a ${ageJours} jours).\nPlanB Tools → Admin → onglet L'Addition.`;
    const res = await tg('sendMessage', { chat_id: chatId, text: texte });
    if (res.ok === true) {
      const { error } = await supa.rpc('pbt_service_config_set', { p_cle: 'laddition_rappel_jeton_le', p_valeur: new Date().toISOString() });
      if (error) console.warn('config_set rappel', error.message);
    }
    return json({ ok: res.ok === true, envoye: true, age_jours: ageJours });
  }

  // --- Digest periodique (pg_cron) ---
  if (action === 'digest') {
    const since = (await getCfg('dernier_digest')) || new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const now = new Date().toISOString();

    const { data: besoins } = await supa
      .from('appro_besoins')
      .select('etablissement, article_nom, ingredient_nom, quantite, unite, urgence, demandeur_nom, date_demande, statut')
      .gt('date_demande', since)
      .in('statut', ['demande', 'valide'])
      .order('etablissement')
      .order('date_demande');

    const { data: interetab } = await supa
      .from('interetab_commandes')
      .select('demandeur_etab, fournisseur_etab, demande_par_nom, lignes, created_at')
      .gt('created_at', since)
      .eq('statut', 'demande');

    const nomEtab = (e: string) => (e === 'freddy' ? 'Freddy' : e === 'liesel' ? 'Liesel' : e);
    const lines: string[] = [];

    const bs = besoins || [];
    if (bs.length) {
      lines.push(`🛒 ${bs.length} nouveau(x) besoin(s) appro :`);
      const parEtab: Record<string, typeof bs> = {};
      for (const b of bs) (parEtab[b.etablissement] ||= []).push(b);
      for (const [etab, list] of Object.entries(parEtab)) {
        lines.push('');
        lines.push(`${nomEtab(etab)} (${list.length}) :`);
        for (const b of list.slice(0, 15)) {
          const nom = b.ingredient_nom || b.article_nom || '?';
          const q = [b.quantite, b.unite].filter((x) => x !== null && x !== undefined && x !== '').join(' ');
          lines.push(`${b.urgence ? '🔴' : '•'} ${nom}${q ? ' — ' + q : ''} (${b.demandeur_nom || '?'})`);
        }
        if (list.length > 15) lines.push(`… et ${list.length - 15} autre(s)`);
      }
    }

    const ic = interetab || [];
    if (ic.length) {
      if (lines.length) lines.push('');
      lines.push(`🏠↔🏠 ${ic.length} demande(s) entre maisons à valider :`);
      for (const c of ic) {
        const det = (Array.isArray(c.lignes) ? c.lignes : [])
          .map((l: Record<string, unknown>) => `${l.nom} ${l.quantite}${l.unite ? ' ' + l.unite : ''}`)
          .join(', ');
        lines.push(`• ${nomEtab(c.demandeur_etab)} → ${nomEtab(c.fournisseur_etab)} (${c.demande_par_nom || '?'}) : ${det}`);
      }
    }

    if (!lines.length) {
      // Rien de neuf : on avance le curseur sans envoyer
      await setCfg('dernier_digest', now);
      return json({ ok: true, envoye: false });
    }

    const heure = new Date().toLocaleString('fr-FR', { timeZone: 'Europe/Paris', hour: '2-digit', minute: '2-digit' });
    const res = await tg('sendMessage', { chat_id: chatId, text: `PlanB Tools — ${heure}\n\n` + lines.join('\n') });
    // Curseur avance seulement si l envoi a reussi (sinon on reessaie au tick suivant)
    if (res.ok === true) await setCfg('dernier_digest', now);
    return json({ ok: res.ok === true, envoye: true, items: bs.length + ic.length });
  }

  return json({ error: 'action inconnue' }, 400);
});
