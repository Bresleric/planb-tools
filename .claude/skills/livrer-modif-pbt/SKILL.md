---
name: livrer-modif-pbt
description: Procedure obligatoire pour livrer une modification de PlanB-Tools (HTML/JS/SQL) — verification branche et pull, test syntaxe JS, bump du service worker, script de commit sans apostrophe, diff montre a Eric, etapes de test iPad. A utiliser des que du code du repo est modifie et doit partir en production, ou quand Eric dit « on livre », « on pousse », « prepare le commit », « mets en ligne ».
---

# Livrer une modif PBT

Eric n'est pas developpeur et il n'y a qu'un seul environnement : la production.
Cette recette se suit **dans l'ordre, sans sauter d'etape**. Si une etape echoue,
on s'arrete, on explique a Eric en francais simple, on corrige, puis on reprend.

## Etape 0 — Avant de toucher au moindre fichier

```bash
cd ~/planb-tools && git branch --show-current && git status --short && git pull --ff-only
```

- Noter la branche active : c'est **sur elle** qu'on poussera (jamais `main` a l'aveugle).
- Si le pull n'est pas fast-forward : STOP, on le dit a Eric, on ne force rien.
- Reperer les fichiers deja modifies **avant** ta modif (ex. `sw.js` d'une livraison
  precedente pas encore poussee) et le signaler a Eric : il faut savoir si on les
  embarque ou non.

## Etape 1 — Faire la modification

Respecter les conventions du CLAUDE.md (vanilla JS, modales, `showToast`, async/try/catch,
jamais « Bonbao », `<\/script>` dans les template literals).

## Etape 2 — Test de syntaxe JS (chaque fichier HTML touche)

Remplacer `FICHIER` par chaque `.html` modifie :

```bash
node -e "const fs=require('fs');const h=fs.readFileSync('FICHIER','utf8');const re=/<script>([\s\S]*?)<\/script>/g;let m,i=0;while((m=re.exec(h))){i++;try{new Function(m[1]);console.log('bloc',i,'OK');}catch(e){console.log('bloc',i,'ERR',e.message);process.exitCode=1;}}"
```

Une seule ligne `ERR` = on corrige avant d'aller plus loin.

## Etape 3 — Bump du service worker

Obligatoire des que la modif est **visible par l'utilisateur** (HTML/JS d'un module).
Sinon les iPads gardent l'ancienne version en cache.

- Ouvrir `sw.js`, ligne `const CACHE_NAME = 'planb-tools-vN';`.
- Si `sw.js` porte deja un bump **pas encore pousse** (vu a l'etape 0) : ne pas
  re-bumper, juste completer le commentaire.
- Sinon : passer a `v(N+1)` et mettre a jour le commentaire (`vN+1 : <sujet> <JJ/MM/AAAA>`).

Pas de bump pour : une migration SQL seule, un script, de la doc.

## Etape 4 — Si la modif touche la base (SQL)

- Ecrire `scripts/migration-<sujet>.sql`, **idempotent** (`IF NOT EXISTS`, `DROP POLICY IF EXISTS`…).
- Toute nouvelle table : `ENABLE ROW LEVEL SECURITY` + policy `pbt_session` (modele du
  CLAUDE.md §8). **Aucune** policy `TO anon`. Aucun PIN en clair.
- Terminer le fichier par la requete de verification `pg_policies`.
- Eric colle le SQL dans Supabase → SQL Editor. Ne pas promettre d'execution via MCP
  sans avoir verifie qu'il n'est pas en lecture seule.

## Etape 5 — Script de commit

Creer `scripts/<sujet-court>.sh` sur ce modele exact :

```bash
#!/bin/bash
# <Resume en une ligne, sans apostrophe> (SW vN)
set -e
cd ~/planb-tools
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git status --short <fichiers> scripts/<sujet-court>.sh
echo "Commit et push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git add <fichiers> scripts/<sujet-court>.sh
git commit -m "<Module> : <ce qui change, pour qui, pourquoi> + bump SW vN

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
echo "Pousse. Publication GitHub Pages en cours (1 a 2 minutes)."
```

Regles :
- `git add` **fichier par fichier** — jamais `git add -A` ni `git add .` (le repo contient
  beaucoup de fichiers non suivis qui ne doivent pas partir).
- Chemins en `~/planb-tools/`, jamais de chemin de VM.
- `read -r REPLY` sans `-p` (zsh).
- **Zero apostrophe** dans le script. Verifier :

```bash
grep -n "'" scripts/<sujet-court>.sh && echo "APOSTROPHE TROUVEE - corriger" || echo "OK sans apostrophe"
```

## Etape 6 — Montrer et attendre le OK

- Montrer a Eric `git status --short` et un resume clair du diff (quoi, ou, pourquoi).
- **Attendre son OK explicite.** Ne jamais lancer le script soi-meme.

## Etape 7 — Message de livraison

Donner a Eric, dans cet ordre :

1. La commande a lancer, seule dans son bloc :
   ```bash
   bash ~/planb-tools/scripts/<sujet-court>.sh
   ```
2. Les migrations SQL a coller d'abord, s'il y en a (et dans quel ordre).
3. Les **etapes de test sur iPad**, concretes et numerotees
   (ex. « ouvre le TAF de Freddy, touche la tache Cervelas, verifie que le scanner s'ouvre »),
   en precisant d'attendre 1 a 2 minutes apres le push et de fermer/rouvrir l'app.
4. Ce qui n'a **pas** ete verifie de mon cote.
