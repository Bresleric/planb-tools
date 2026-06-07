// Injecte un garde-fou "mode developpement" dans chaque resetInactivity().
// Si sessionStorage.planb_dev_nolock === '1', le minuteur d'inactivite ne s'arme jamais.
// Idempotent : ne re-patche pas un fichier deja traite.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const files = [
  'index.html',
  'caisse/index.html',
  'planb-tools-update/index.html',
  'temperatures/index.html',
  'cartons-jvr/index.html',
  'objectifs/index.html',
  'ventes/index.html',
  'admin/index.html',
  'dashboard/index.html',
  'approvisionnement/index.html',
  // briefing/index.html : volontairement exclu (travail "archivage" en cours non commite, garde a ajouter avec ce commit-la)
  'receptions/elis.html',
  'production/index.html',
  'numerisations/index.html',
  'checklist/index.html',
  'taf/index.html',
];

const guard =
  "\n    // Mode developpement (admin) : pas de deconnexion auto pour cette session" +
  "\n    try { if (sessionStorage.getItem('planb_dev_nolock') === '1') { if (inactivityTimer) clearTimeout(inactivityTimer); return; } } catch(e){}";

const re = /function resetInactivity\(\) \{/;

let changed = 0;
for (const rel of files) {
  const f = path.join(root, rel);
  let s = fs.readFileSync(f, 'utf8');
  if (s.includes('planb_dev_nolock')) { console.log('skip (deja patche) ', rel); continue; }
  if (!re.test(s)) { console.log('!! ANCRE INTROUVABLE  ', rel); continue; }
  s = s.replace(re, (m) => m + guard);
  fs.writeFileSync(f, s);
  console.log('patche               ', rel);
  changed++;
}
console.log('\nTermine. Fichiers modifies : ' + changed);
