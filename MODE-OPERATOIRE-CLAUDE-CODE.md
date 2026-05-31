# Mode opératoire — Session Claude Code sur PlanB-Tools

> Tient sur une page A4. Imprime ou garde en favori.

## Au démarrage d'une session (5 étapes — 30 secondes)

1. Ouvre le **Terminal** sur ton Mac.

2. Va dans le dossier git du projet :
   ```
   cd ~/planb-tools
   ```
   (Pas dans iCloud. Jamais.)

3. Récupère les dernières modifs poussées entre-temps (par Cowork ou un collègue) :
   ```
   git pull --ff-only
   ```
   Si tu vois "Already up to date." → parfait.
   Si tu vois une erreur **« Not possible to fast-forward »** → STOP. Tu as un commit local non poussé. Appelle Cowork avant de continuer.

4. Lance Claude Code :
   ```
   claude
   ```

5. Première phrase à Claude Code (toujours) :
   > « Lis le CLAUDE.md puis dis-moi ce sur quoi je travaille aujourd'hui. »

   → Claude Code lit le playbook, te confirme le contexte. Tu enchaînes avec ta demande.

## Pendant la session

- Décris ce que tu veux faire en français normal, comme avec moi (Cowork).
- Claude Code va lire des fichiers, te proposer un plan, puis modifier. **Il te montre le diff avant de commiter**.
- Quand il te demande "OK pour commit ?" → relis vite, dis OUI ou demande un ajustement.
- Il pousse lui-même via le script `scripts/<feature>.sh`. Tu n'as plus besoin de lancer `bash scripts/...` manuellement comme avant.

## À l'arrêt d'une session (3 étapes — 20 secondes)

1. Vérifie que tout est commité et poussé :
   ```
   git status
   ```
   → Tu dois voir **"working tree clean"** et **"Your branch is up to date with 'origin/main'"**.
   Si non, demande à Claude Code de finir le commit + push avant de fermer.

2. Quitte Claude Code :
   ```
   /exit
   ```
   (ou `Ctrl+C` deux fois)

3. Ferme le Terminal si tu n'en as plus besoin.

## Si tu reviens vers Cowork (moi) après Claude Code

- Dis-moi simplement « j'ai fini une session Claude Code sur [sujet] » — je récupère les commits récents et je te remets en contexte.
- Si tu as un bug visuel sur l'iPad après la session, prends un screenshot, envoie-le-moi, je diagnostique et je te dis quoi faire faire à Claude Code lors de la prochaine session.

## En cas de pépin

| Symptôme | Réflexe |
|---|---|
| Erreur `git pull --ff-only` au démarrage | NE PAS forcer. Appelle Cowork pour résoudre. |
| Claude Code modifie 200 lignes pour un petit fix | Demande-lui de **réduire le diff**. Il refait. |
| Le push échoue avec "rejected" | Quelqu'un a poussé entre temps. `git pull --rebase` puis retente. Claude Code sait gérer. |
| L'iPad ne voit pas la modif après push | Le service worker cache. Bumpe `sw.js` `CACHE_NAME` `vN → v(N+1)`. |
| Tu te sens perdu | **Tape `/clear` puis recommence** avec « lis le CLAUDE.md ». |

## Règles d'or

1. **Un seul dossier pour le code** : `~/planb-tools/`. **Plus de copie iCloud du code.**
2. **`git pull` au début**, **`git status` à la fin**. Sans exception.
3. **Tu valides chaque commit** avant qu'il parte. Ne dis pas OUI sans regarder le résumé.
4. **Si Claude Code te propose une refonte > 50 lignes**, demande-lui d'abord d'expliquer pourquoi en 3 phrases avant d'accepter.
5. **En cas de doute, reviens vers Cowork** — c'est mieux d'arbitrer entre deux outils plutôt que de pousser quelque chose qui te mettra en panne demain.

---

**Le contrat** : Claude Code respecte le `CLAUDE.md` qui est à la racine du repo. Ce playbook est le condensé de toutes les leçons accumulées sur PBT — il évite à Claude Code de répéter les bourdes du passé.
