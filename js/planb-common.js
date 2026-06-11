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
})(window);
