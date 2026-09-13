#!/bin/bash
# ============================================================================
# Grand rangement PBT : archiver dans le repo les vieux fichiers non versionnes
# (scripts de commit de la periode Cowork, migrations SQL, docs PDF).
# A lancer sur la machine atelier : bash scripts/rangement-archives.sh
# Rejouable sans risque ; utilisable aussi sur le MacMini pour ses doublons.
# ============================================================================
set -e
cd "$HOME/planb-tools"

echo "== Mise a jour du repo avant rangement =="
git pull --ff-only origin main

mkdir -p scripts/archive-2026 docs

moved=0
ignored=0
while IFS= read -r f; do
  base="$(basename "$f")"
  case "$base" in
    .DS_Store) rm -f "$f"; continue ;;
  esac
  case "$f" in
    scripts/archive-2026/*) continue ;;
  esac
  case "$f" in
    *.sh|*.sql|*.txt) dest="scripts/archive-2026/$base" ;;
    *.pdf|*.md) dest="docs/$base" ;;
    *) echo "IGNORE (a trier a la main) : $f"; ignored=$((ignored+1)); continue ;;
  esac
  if [ -e "$dest" ]; then
    if cmp -s "$f" "$dest"; then
      rm "$f"
      echo "DOUBLON identique, supprime : $f"
    else
      mv "$f" "$dest.variante"
      echo "VARIANTE archivee : $f -> $dest.variante"
      moved=$((moved+1))
    fi
    continue
  fi
  mv "$f" "$dest"
  echo "ARCHIVE : $f -> $dest"
  moved=$((moved+1))
done < <(git ls-files --others --exclude-standard)

if [ "$moved" -eq 0 ]; then
  echo "Rien a archiver - le dossier est deja propre."
  exit 0
fi

git add scripts/archive-2026 docs
git commit -m "chore: grand rangement - archiver les vieux scripts et fichiers non versionnes de la periode Cowork" -m "Scripts de commit, migrations SQL et docs restes hors du repo depuis mai-juin, archives pour tracabilite (decision Eric, promise dans le brief du 8 juin)." -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push origin main
echo "== Termine : $moved fichier(s) archives et pousses sur GitHub =="
if [ "$ignored" -gt 0 ]; then
  echo "NB : $ignored fichier(s) ignores car type inattendu - me montrer la liste ci-dessus."
fi
