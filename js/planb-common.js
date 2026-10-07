// ============================================================================
// PlanB-Tools — Socle commun JS
// ----------------------------------------------------------------------------
// But : centraliser la configuration Supabase (URL + cle anon publique) qui
// etait jusqu ici copiee-collee dans ~36 fichiers. Le jour ou la cle change,
// on ne modifie QUE ce fichier.
//
// Chargement : ce script doit etre inclus APRES la librairie supabase-js et
// AVANT le <script> du module. ATTENTION : chemin RELATIF (le site est servi
// sous /planb-tools/ sur GitHub Pages, un chemin absolu /js/... pointerait au
// mauvais endroit). Depuis un module a la racine (ex. ventes/index.html) :
//
//   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
//   <script src="../js/planb-common.js"></script>
//   <script> ... code du module ... const sb = PLANB.client(); ... </script>
//
// Note securite : SUPABASE_KEY est la cle ANON (role:anon), publique par
// nature cote front Supabase. Ce n est PAS un secret. La protection des
// donnees repose sur les policies RLS cote base, pas sur cette cle.
// ============================================================================

(function (global) {
  'use strict';

  var SUPABASE_URL = 'https://dzrherfavgiuygnimtux.supabase.co';
  var SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ';

  global.PLANB = global.PLANB || {};
  global.PLANB.SUPABASE_URL = SUPABASE_URL;
  global.PLANB.SUPABASE_KEY = SUPABASE_KEY;

  // Client Supabase en singleton : evite de recreer un client a chaque appel.
  // persistSession est actif par defaut : tous les modules (meme origine)
  // partagent la session auth via localStorage, donc le JWT suit partout.
  var _client = null;
  global.PLANB.client = function () {
    if (!_client) {
      if (!global.supabase || typeof global.supabase.createClient !== 'function') {
        throw new Error('[PLANB] supabase-js doit etre charge avant planb-common.js');
      }
      _client = global.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
    }
    return _client;
  };

  // ==========================================================================
  // Sessions securisees (phase 2 securite, 07/10/2026)
  // Le front ouvre une connexion Supabase ANONYME (auth.uid cote serveur),
  // puis les RPC pbt_* gerent la session PBT (PIN hache, anti force brute).
  // ==========================================================================

  // Garantit une session auth Supabase (anonyme) avant tout appel pbt_*.
  global.PLANB.assurerSession = async function () {
    var sb = global.PLANB.client();
    var s = await sb.auth.getSession();
    if (s && s.data && s.data.session) return s.data.session;
    var r = await sb.auth.signInAnonymously();
    if (r.error) throw new Error('Connexion au serveur impossible : ' + r.error.message);
    return r.data.session;
  };

  // Connexion par PIN. Renvoie { user, doit_changer_code, device, expire_le }.
  global.PLANB.login = async function (pin, deviceToken, memoriser) {
    await global.PLANB.assurerSession();
    var sb = global.PLANB.client();
    var r = await sb.rpc('pbt_login', {
      p_pin: pin,
      p_device_token: deviceToken || null,
      p_memoriser: !!memoriser
    });
    if (r.error) throw new Error(r.error.message || 'Connexion refusee');
    return r.data;
  };

  global.PLANB.logout = async function () {
    try {
      var sb = global.PLANB.client();
      await sb.rpc('pbt_logout');
    } catch (e) { /* la deconnexion locale suffit */ }
  };

  // Verification PIN (ecrans de verrouillage, signatures des modules).
  // Renvoie { id, nom, initiales, role, equipe, etablissement,
  // acces_etablissements } ou null si code inconnu.
  global.PLANB.verifierPin = async function (pin) {
    await global.PLANB.assurerSession();
    var sb = global.PLANB.client();
    var r = await sb.rpc('pbt_verifier_pin', { p_pin: pin });
    if (r.error) throw new Error(r.error.message || 'Verification impossible');
    return r.data; // null si PIN inconnu
  };

  global.PLANB.changerPin = async function (ancien, nouveau) {
    var sb = global.PLANB.client();
    var r = await sb.rpc('pbt_changer_pin', { p_ancien: ancien, p_nouveau: nouveau });
    if (r.error) throw new Error(r.error.message || 'Changement refuse');
    return r.data;
  };

  global.PLANB.activerAppareil = async function (code) {
    await global.PLANB.assurerSession();
    var sb = global.PLANB.client();
    var r = await sb.rpc('pbt_activer_appareil', { p_code: code });
    if (r.error) throw new Error(r.error.message || 'Activation impossible');
    return r.data; // { id, nom, device_token, actif } ou { error: 'already_activated' }
  };

  // Session PBT courante cote serveur (null si expiree/revoquee).
  global.PLANB.maSession = async function () {
    await global.PLANB.assurerSession();
    var sb = global.PLANB.client();
    var r = await sb.rpc('pbt_ma_session');
    if (r.error) return null;
    return r.data;
  };

  // Erreur d autorisation (session expiree / RLS) ? -> retour portail.
  // A appeler dans les catch des modules : if (PLANB.erreurAuth(e)) return;
  global.PLANB.erreurAuth = function (e) {
    var msg = String((e && (e.message || e.error_description || e.code)) || e || '');
    var auth = /jwt|401|session requise|row-level security|permission denied/i.test(msg);
    if (auth) {
      try { sessionStorage.clear(); } catch (err) {}
      try { alert('Session expiree, reconnectez-vous.'); } catch (err) {}
      window.location.href = (window.location.pathname.indexOf('/planb-tools/') >= 0 &&
        window.location.pathname.split('/').length > 3) ? '../' : './';
    }
    return auth;
  };
})(window);
