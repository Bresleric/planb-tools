# Outils du cadencier Noel 2026

Chaine de fabrication du tableur `Cadencier_Noel_2026.xlsx` (relancer dans cet ordre, depuis un dossier de travail) :

1. `swiftc -O -o pdf2lines pdf2lines.swift` puis `./pdf2lines txt/ chemin/vers/*.pdf` : convertit les factures PDF en texte ligne par ligne (PDFKit natif Mac, rien a installer).
2. `python3 parse_factures.py txt/ lignes_factures.csv` : lit les lignes articles (Essentiel RHF, Sapam, Promocash, Distribution Iller, Choucroute Weber, Metro, Koch), date de livraison = date du bon de livraison, dedoublonnage par numero de facture.
3. `python3 build_cadencier.py chemin/sortie.xlsx` : attend `ventes_noel_2025.csv` et `lignes_factures.csv` dans le dossier courant.

Sources :
- Ventes : exports L Addition « Products » a la racine iCloud (`199-laddition-Products-...` = Chez Tante Liesel, `2282-laddition-Products-...` = Freddy), feuille `ProductAnalyticsByDatesQTE`.
- Factures : iCloud `Factures_2025/` et `Factures_2026/`, fichiers `Fact <Fournisseur> AAAAMMJJ <numero>.pdf` (attention : certains sont mal nommes, le fournisseur est detecte dans le contenu).
