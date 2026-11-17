# -*- coding: utf-8 -*-
"""Construit le tableur Cadencier Noel 2026 a partir de ventes_noel_2025.csv et lignes_factures.csv"""
import csv, sys, collections, datetime as dt, re, math
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter as L
from openpyxl.comments import Comment

OUT = sys.argv[1] if len(sys.argv) > 1 else "/Users/eric/planb-tools/docs/cadencier-noel-2026/Cadencier_Noel_2026.xlsx"
D0, D1 = dt.date(2025,11,27), dt.date(2026,1,10)          # periode de reference 2025
E0, E1 = dt.date(2026,11,27), dt.date(2027,1,10)          # periode cible 2026
FERMES_2026 = {dt.date(2026,12,24), dt.date(2026,12,25), dt.date(2026,12,26), dt.date(2027,1,1)}
JOURS = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim']
TOURNEES = {'Promocash':[1,1,1,1,1,1,0], 'Distribution Iller':[1,1,1,1,1,0,0], 'Koch':[1,1,1,1,1,1,0], 'Essentiel RHF':[1,1,1,1,1,0,0], 'Sapam':[1,1,1,1,1,1,0], 'Choucroute Weber':[1,1,1,1,1,0,0], 'Metro':[1,1,1,1,1,1,0]}
ETABS = [('freddy','Freddy'), ('liesel','Liesel')]
NON_ALIM = re.compile(r"GANT|SAC POUB|SAC S/VIDE|FILM ETIR|PAPIER|BOBINE|DESODOR|SANYTOL|EPONGE|TAMPON|NETT|DESINF|LESSIVE|LIQUIDE VAISS|SERVIETTE|ESSUIE|ROULEAU|BAC GASTRO|SPIRALE|CAISSE IFCO|FRAIS DE LIVR|FRAIS FORF|ECO.?PART|EMBALLAGE|CONSIGNE|VAISSELLE|BOUGIE|ALLUME|PILE|AMPOULE|JAVEL|SOPALIN|CELLOPHANE|ALU |BARQUETTE VIDE|GOBELET|PAILLE|TOUILLETTE|SET DE TABLE|NAPPE|TORCHON|CHIFFON|BALAI|SEAU |BROSSE|PRODUIT WC|DEGRAISS|DETARTR|VIGNETTE|SERVICE", re.I)

font = 'Arial'
F = lambda **k: Font(name=font, **k)
HDR = PatternFill('solid', fgColor='1F3864'); HDRF = F(bold=True, color='FFFFFF')
INPUT = PatternFill('solid', fgColor='FFFF00'); BLUE = F(color='0000FF')
SUB = PatternFill('solid', fgColor='D9E1F2'); GREY = PatternFill('solid', fgColor='F2F2F2')
thin = Side(style='thin', color='BFBFBF'); BORDER = Border(left=thin, right=thin, top=thin, bottom=thin)

def hdr(ws, row, values, widths=None):
    for i, v in enumerate(values, 1):
        c = ws.cell(row=row, column=i, value=v); c.fill = HDR; c.font = HDRF; c.alignment = Alignment(wrap_text=True, vertical='center', horizontal='center'); c.border = BORDER
    if widths:
        for i, w in enumerate(widths, 1): ws.column_dimensions[L(i)].width = w
    ws.row_dimensions[row].height = 32
def style_all(ws, r0, r1, c0, c1):
    for r in range(r0, r1+1):
        for c in range(c0, c1+1):
            cell = ws.cell(row=r, column=c); cell.border = BORDER
            if cell.font.name != font: cell.font = F(bold=cell.font.bold, color=cell.font.color.rgb if cell.font.color and isinstance(cell.font.color.rgb, str) else None)

# ---------- donnees ----------
ventes = list(csv.DictReader(open('ventes_noel_2025.csv')))
for v in ventes: v['quantite'] = float(v['quantite']); v['d'] = dt.date.fromisoformat(v['date'])
lignes = list(csv.DictReader(open('lignes_factures.csv')))
for l in lignes:
    l['qte'] = float(l['qte'] or 0); l['montant_ht'] = float(l['montant_ht'] or 0); l['pu_ht'] = float(l['pu_ht'] or 0)
    l['d'] = dt.date.fromisoformat(l['date_livraison']) if l['date_livraison'] else None
    l['designation'] = re.sub(r'\s+', ' ', l['designation'].upper()).strip()
    l['alim'] = not NON_ALIM.search(l['designation'])
lignes = [l for l in lignes if l['d'] and D0 - dt.timedelta(days=7) <= l['d'] <= D1 and l['etablissement'] in ('freddy','liesel')]
jours_ref = [D0 + dt.timedelta(days=i) for i in range((D1-D0).days+1)]
jours_cible = [E0 + dt.timedelta(days=i) for i in range((E1-E0).days+1)]

plats = collections.defaultdict(float); alc = collections.defaultdict(float); nonalc = collections.defaultdict(float)
prod = collections.defaultdict(float); prodtot = collections.defaultdict(float)
for v in ventes:
    k = (v['etablissement'], v['d'])
    if v['typologie'] == 'Solide': plats[k] += v['quantite']; prod[(v['etablissement'], v['d'], v['produit'])] += v['quantite']; prodtot[(v['etablissement'], v['produit'])] += v['quantite']
    elif v['typologie'] == 'Liquide (Alcool)': alc[k] += v['quantite']
    else: nonalc[k] += v['quantite']
jours_ouverts = {e: {d for d in jours_ref if plats[(e,d)] > 0} for e,_ in ETABS}

wb = Workbook()
# ---------- 1. Lisez-moi ----------
ws = wb.active; ws.title = 'Lisez-moi'
ws.column_dimensions['A'].width = 120
texte = [
 ("CADENCIER DES APPROVISIONNEMENTS - MARCHE DE NOEL 2026", True),
 ("Periode cible : du vendredi 27 novembre 2026 au dimanche 10 janvier 2027. Etablissements : Freddy et Chez Tante Liesel.", False),
 ("", False),
 ("SOURCES", True),
 ("- Ventes : exports L'Addition « Products » (quantites par produit et par jour), comptes 2282 (Freddy) et 199 (Liesel), du 27/11/2025 au 10/01/2026.", False),
 ("- Achats : factures PDF du dossier iCloud Factures_2025 et Factures_2026, lues ligne par ligne (Essentiel RHF, Sapam, Promocash, Distribution Iller, Choucroute Weber, Metro). La date retenue est celle du BON DE LIVRAISON quand la facture est periodique, sinon la date de facture.", False),
 ("- Jours de tournee 2026 (saisis par Eric) : Promocash lun-sam, Iller lun-ven, Koch lun-sam, Essentiel lun-ven, Sapam lun-sam. Modifiables dans l'onglet Hypotheses.", False),
 ("", False),
 ("METHODE", True),
 ("1. Chaque jour 2026 est rapproche du meme jour de semaine de 2025 (J - 364 jours). Les plats prevus = plats vendus ce jour de reference x coefficient de croissance (onglet Hypotheses).", False),
 ("2. Pour chaque article achete en 2025, on calcule la quantite consommee pour 100 plats vendus entre la premiere et la derniere livraison du fournisseur (onglet Achats 2025 articles, colonnes N et O). Pour Koch et Iller, livres seulement en janvier 2026, le ratio repose donc sur une dizaine de jours : a relire avec prudence.", False),
 ("3. Les onglets « Commandes 2026 - fournisseur » proposent, pour chaque jour de livraison, la quantite couvrant les plats prevus jusqu'a la livraison suivante (flux tendu). Les jours de livraison reprennent le rythme observe en 2025, limite aux jours de tournee 2026.", False),
 ("4. L'onglet Negociation additionne les quantites par article et fournisseur pour la periode : c'est la base d'engagement.", False),
 ("", False),
 ("CELLULES A MODIFIER (fond jaune, texte bleu)", True),
 ("- Hypotheses : coefficients de croissance Freddy et Liesel, jours de tournee, seuils de la base essentielle.", False),
 ("- Cadencier 2026 : colonne Ouvert (1 = ouvert, 0 = ferme). Par defaut : fermes les 24, 25, 26 decembre 2026 et le 1er janvier 2027, comme en 2025.", False),
 ("Tout le reste est calcule par formules et se met a jour automatiquement.", False),
 ("", False),
 ("LIMITES CONNUES", True),
 ("- Koch et Distribution Iller n'apparaissent dans les factures qu'a partir de janvier 2026 : pas de reference 2025 pour eux. Les viandes et charcuteries 2025 venaient d'Essentiel, Metro et Promocash.", False),
 ("- Les achats de Liesel en 2025 sont faibles par rapport a ses ventes (surtout Metro) : une partie de sa production venait probablement de la cuisine de Freddy. Les ratios par 100 plats de Freddy integrent donc une part de Liesel.", False),
 ("- Les quantites proposees sont des points de depart a relire par la cuisine, pas des commandes fermes.", False),
]
for i, (t, b) in enumerate(texte, 1):
    c = ws.cell(row=i, column=1, value=t); c.font = F(bold=b, size=12 if b else 10); c.alignment = Alignment(wrap_text=True, vertical='top')

# ---------- 2. Hypotheses ----------
hy = wb.create_sheet('Hypotheses')
hy.column_dimensions['A'].width = 34
for col in 'BCDEFGH': hy.column_dimensions[col].width = 9
hy['A1'] = 'HYPOTHESES (cellules jaunes modifiables)'; hy['A1'].font = F(bold=True, size=12)
hy['A3'] = 'Coefficient de croissance Freddy'; hy['B3'] = 1.0
hy['A4'] = 'Coefficient de croissance Liesel'; hy['B4'] = 1.0
hy['A5'] = 'Seuil base essentielle : nb de livraisons 2025 minimum'; hy['B5'] = 3
hy['A6'] = 'Seuil base essentielle : montant HT 2025 minimum (EUR)'; hy['B6'] = 100
for r in (3,4,5,6):
    hy.cell(row=r, column=2).fill = INPUT; hy.cell(row=r, column=2).font = BLUE; hy.cell(row=r, column=1).font = F()
hy['B3'].number_format = '0.00'; hy['B4'].number_format = '0.00'
hy['B3'].comment = Comment('1,00 = memes volumes qu en 2025. 1,10 = +10 %. Saisi par Eric.', 'PBT')
hdr(hy, 8, ['Jours de tournee 2026 (1 = livre, 0 = ne livre pas)'] + JOURS)
for i, (sup, days) in enumerate(TOURNEES.items(), 9):
    hy.cell(row=i, column=1, value=sup).font = F()
    for j, d in enumerate(days, 2):
        c = hy.cell(row=i, column=j, value=d); c.fill = INPUT; c.font = BLUE; c.alignment = Alignment(horizontal='center')
TOURNEE_ROW = {sup: 9+i for i, sup in enumerate(TOURNEES)}
style_all(hy, 8, 8+len(TOURNEES), 1, 8)
hy.cell(row=18, column=1, value='Koch & Fils : pas de facture 2025 sur la periode (fournisseur depuis 2026). A completer manuellement.').font = F(italic=True, color='808080')

# ---------- 3. Ventes 2025 par etablissement ----------
VENTES_WS = {}
for e, nom in ETABS:
    vs = wb.create_sheet(f'Ventes 2025 {nom}'); VENTES_WS[e] = vs.title
    tops = [p for p, q in sorted(((p, q) for (ee, p), q in prodtot.items() if ee == e), key=lambda x: -x[1])[:20]]
    cols = ['Date', 'Jour', 'Ouvert', 'Plats (solides)', 'Boissons alcool', 'Boissons sans alcool'] + tops
    hdr(vs, 1, cols, [12, 6, 7, 10, 10, 10] + [13]*len(tops))
    for i, d in enumerate(jours_ref, 2):
        vs.cell(row=i, column=1, value=d).number_format = 'DD/MM/YYYY'
        vs.cell(row=i, column=2, value=JOURS[d.weekday()])
        vs.cell(row=i, column=3, value=1 if d in jours_ouverts[e] else 0)
        vs.cell(row=i, column=4, value=plats[(e,d)]); vs.cell(row=i, column=5, value=alc[(e,d)]); vs.cell(row=i, column=6, value=nonalc[(e,d)])
        for j, p in enumerate(tops, 7): vs.cell(row=i, column=j, value=prod.get((e, d, p), 0))
    last = len(jours_ref) + 1; tot = last + 1
    vs.cell(row=tot, column=1, value='TOTAL periode').font = F(bold=True)
    vs.cell(row=tot, column=3, value=f'=SUM(C2:C{last})')
    for j in range(4, 7 + len(tops)): vs.cell(row=tot, column=j, value=f'=SUM({L(j)}2:{L(j)}{last})').font = F(bold=True)
    vs.cell(row=tot+1, column=1, value='Moyenne par jour ouvert').font = F(italic=True)
    for j in range(4, 7 + len(tops)): vs.cell(row=tot+1, column=j, value=f'=IF(C{tot}=0,0,{L(j)}{tot}/C{tot})').number_format = '0.0'
    style_all(vs, 1, tot+1, 1, 6 + len(tops)); vs.freeze_panes = 'C2'
    VENTES_WS[e+'_tot'] = f"'{vs.title}'!$D${tot}"; VENTES_WS[e+'_rows'] = (2, last)

# ---------- 4. Livraisons 2025 ----------
lv = wb.create_sheet('Livraisons 2025')
jours_liv = [D0 - dt.timedelta(days=7) + dt.timedelta(days=i) for i in range((D1-D0).days+8)]
couples = sorted({(l['fournisseur'], l['etablissement']) for l in lignes})
hdr(lv, 1, ['Date', 'Jour'] + [f'{s} - {dict(ETABS)[e]}' for s, e in couples] + ['Total HT jour'], [12, 6] + [16]*len(couples) + [12])
mt = collections.defaultdict(float); nbl = collections.defaultdict(set)
for l in lignes: mt[(l['d'], l['fournisseur'], l['etablissement'])] += l['montant_ht']; nbl[(l['d'], l['fournisseur'], l['etablissement'])].add(l['bl'] or l['facture'])
for i, d in enumerate(jours_liv, 2):
    lv.cell(row=i, column=1, value=d).number_format = 'DD/MM/YYYY'; lv.cell(row=i, column=2, value=JOURS[d.weekday()])
    for j, (s, e) in enumerate(couples, 3):
        v = mt.get((d, s, e)); c = lv.cell(row=i, column=j, value=round(v, 2) if v else None); c.number_format = '#,##0.00'
        if v: c.fill = SUB
    lv.cell(row=i, column=3+len(couples), value=f'=SUM(C{i}:{L(2+len(couples))}{i})').number_format = '#,##0.00'
    if d.weekday() == 6:
        for j in range(1, 4+len(couples)): lv.cell(row=i, column=j).fill = GREY if not lv.cell(row=i, column=j).fill.fgColor.rgb.endswith('D9E1F2') else SUB
last = len(jours_liv) + 1
lv.cell(row=last+1, column=1, value='TOTAL HT').font = F(bold=True)
lv.cell(row=last+2, column=1, value='Nb jours livres').font = F(bold=True)
for j in range(3, 4+len(couples)):
    lv.cell(row=last+1, column=j, value=f'=SUM({L(j)}2:{L(j)}{last})').number_format = '#,##0.00'
    lv.cell(row=last+2, column=j, value=f'=COUNT({L(j)}2:{L(j)}{last})')
# rythme observe par jour de semaine
r0 = last + 5
lv.cell(row=r0-1, column=1, value='Rythme observe 2025 : nombre de livraisons par jour de semaine (montant HT en EUR)').font = F(bold=True)
hdr(lv, r0, ['Fournisseur - etab'] + JOURS + ['Total livraisons'])
for i, (s, e) in enumerate(couples, r0+1):
    lv.cell(row=i, column=1, value=f'{s} - {dict(ETABS)[e]}')
    for wd in range(7):
        lv.cell(row=i, column=2+wd, value=f'=SUMPRODUCT((WEEKDAY($A$2:$A${last},2)={wd+1})*({L(3+couples.index((s,e)))}$2:{L(3+couples.index((s,e)))}${last}>0))')
    lv.cell(row=i, column=9, value=f'=SUM(B{i}:H{i})')
style_all(lv, 1, last+2, 1, 3+len(couples)); style_all(lv, r0, r0+len(couples), 1, 9); lv.freeze_panes = 'C2'

# ---------- 5. Achats 2025 articles ----------
import statistics
livdates = collections.defaultdict(set)
for l in lignes:
    if l['d'] <= D1: livdates[(l['fournisseur'], l['etablissement'])].add(l['d'])
FENETRE = {}
for k, ds in livdates.items():
    ds = sorted(ds); gaps = [(b-a).days for a, b in zip(ds, ds[1:])]
    gap = int(statistics.median(gaps)) if gaps else 3
    w0 = max(D0, ds[0]); w1 = min(D1, ds[-1] + dt.timedelta(days=max(gap, 1) - 1))
    pw = sum(plats[(k[1], d)] for d in jours_ref if w0 <= d <= w1)
    FENETRE[k] = (w0, w1, pw if pw > 0 else sum(plats[(k[1], d)] for d in jours_ref))
ac = wb.create_sheet('Achats 2025 articles')
cols = ['Fournisseur', 'Etab', 'Article', 'Unite', 'Alimentaire', 'Nb livraisons', 'Qte totale 2025', 'Montant HT 2025', 'PU moyen HT', 'Qte moyenne par livraison', 'Qte pour 100 plats', 'Base essentielle', 'Jours livres 2025', 'Fenetre de livraison 2025', 'Plats vendus sur la fenetre']
hdr(ac, 1, cols, [18, 8, 44, 7, 10, 10, 12, 12, 10, 12, 12, 11, 30, 22, 12])
ac['O1'].comment = Comment('Plats (solides) vendus par l etablissement entre la premiere et la derniere livraison du fournisseur sur la periode. Sert de denominateur a la Qte pour 100 plats : indispensable pour Koch et Iller, presents seulement en janvier 2026.', 'PBT')
agg = {}
for l in lignes:
    k = (l['fournisseur'], l['etablissement'], l['designation'])
    a = agg.setdefault(k, dict(unite=l['unite'], alim=l['alim'], q=0.0, m=0.0, livs=set(), days=collections.Counter()))
    a['q'] += l['qte']; a['m'] += l['montant_ht']; a['livs'].add((l['d'], l['bl'] or l['facture'])); a['days'][JOURS[l['d'].weekday()]] += 1
order = sorted(agg.items(), key=lambda kv: (kv[0][0], kv[0][1], -kv[1]['m']))
ART_ROW = {}
for i, ((s, e, art), a) in enumerate(order, 2):
    ART_ROW[(s, e, art)] = i
    ac.cell(row=i, column=1, value=s); ac.cell(row=i, column=2, value=dict(ETABS)[e]); ac.cell(row=i, column=3, value=art); ac.cell(row=i, column=4, value=a['unite'])
    ac.cell(row=i, column=5, value='oui' if a['alim'] else 'non')
    ac.cell(row=i, column=6, value=len(a['livs'])); ac.cell(row=i, column=7, value=round(a['q'], 3)).number_format = '#,##0.00'
    ac.cell(row=i, column=8, value=round(a['m'], 2)).number_format = '#,##0.00'
    ac.cell(row=i, column=9, value=f'=IF(G{i}=0,0,H{i}/G{i})').number_format = '#,##0.00'
    ac.cell(row=i, column=10, value=f'=IF(F{i}=0,0,G{i}/F{i})').number_format = '#,##0.0'
    w0, w1, pw = FENETRE[(s, e)]
    ac.cell(row=i, column=11, value=f'=IF(O{i}=0,0,G{i}/O{i}*100)').number_format = '#,##0.00'
    ac.cell(row=i, column=14, value=f'{w0:%d/%m/%Y} - {w1:%d/%m/%Y}')
    ac.cell(row=i, column=15, value=pw).number_format = '#,##0'
    ac.cell(row=i, column=12, value=f'=IF(AND(E{i}="oui",OR(F{i}>=Hypotheses!$B$5,H{i}>=Hypotheses!$B$6)),"OUI","")')
    ac.cell(row=i, column=13, value=', '.join(f'{j} x{n}' for j, n in a['days'].most_common()))
last_ac = len(order) + 1
style_all(ac, 1, last_ac, 1, 15); ac.freeze_panes = 'D2'; ac.auto_filter.ref = f'A1:O{last_ac}'

# ---------- 6. Cadencier 2026 ----------
cd = wb.create_sheet('Cadencier 2026')
sups = list(TOURNEES.keys())
cols = ['Date', 'Jour', 'Ouvert', 'Date ref. 2025', 'Plats ref. Freddy', 'Plats prevus Freddy', 'Plats ref. Liesel', 'Plats prevus Liesel', 'Total plats prevus'] + [f'{s}\nlivrable' for s in sups] + ['Livraisons observees a la date de ref. 2025']
hdr(cd, 1, cols, [12, 6, 7, 12, 10, 10, 10, 10, 10] + [11]*len(sups) + [60])
ref_of = {}
for i, d in enumerate(jours_cible, 2):
    ref = d - dt.timedelta(days=364)
    if ref not in jours_ouverts['freddy'] and ref not in jours_ouverts['liesel'] and (ref - dt.timedelta(days=7)) in jours_ouverts['freddy'] and ref not in {dt.date(2025,12,24), dt.date(2025,12,25), dt.date(2025,12,26), dt.date(2026,1,1)}:
        ref = ref - dt.timedelta(days=7)
    ref_of[d] = ref
    cd.cell(row=i, column=1, value=d).number_format = 'DD/MM/YYYY'; cd.cell(row=i, column=2, value=JOURS[d.weekday()])
    ouvert = 0 if d in FERMES_2026 else 1
    c = cd.cell(row=i, column=3, value=ouvert); c.fill = INPUT; c.font = BLUE; c.alignment = Alignment(horizontal='center')
    cd.cell(row=i, column=4, value=ref).number_format = 'DD/MM/YYYY'
    for e, cref, cprev, coef in (('freddy', 5, 6, '$B$3'), ('liesel', 7, 8, '$B$4')):
        r2, rl = VENTES_WS[e+'_rows']
        cd.cell(row=i, column=cref, value=f"=IFERROR(INDEX('{VENTES_WS[e]}'!$D${r2}:$D${rl},MATCH(D{i},'{VENTES_WS[e]}'!$A${r2}:$A${rl},0)),0)").number_format = '0'
        cd.cell(row=i, column=cprev, value=f'=ROUND({L(cref)}{i}*Hypotheses!{coef}*C{i},0)').number_format = '0'
    cd.cell(row=i, column=9, value=f'=F{i}+H{i}').number_format = '0'
    for j, s in enumerate(sups, 10):
        cd.cell(row=i, column=j, value=f'=INDEX(Hypotheses!$B${TOURNEE_ROW[s]}:$H${TOURNEE_ROW[s]},WEEKDAY(A{i},2))').alignment = Alignment(horizontal='center')
    obs = sorted({f"{l['fournisseur']} ({dict(ETABS)[l['etablissement']]}) {mt[(ref, l['fournisseur'], l['etablissement'])]:.0f} EUR" for l in lignes if l['d'] == ref})
    cd.cell(row=i, column=10+len(sups), value=' | '.join(obs))
    if d.weekday() == 6:
        for j in (1, 2, 4): cd.cell(row=i, column=j).fill = GREY
last_cd = len(jours_cible) + 1
cd.cell(row=last_cd+1, column=1, value='TOTAL').font = F(bold=True)
for j in (3, 5, 6, 7, 8, 9): cd.cell(row=last_cd+1, column=j, value=f'=SUM({L(j)}2:{L(j)}{last_cd})').font = F(bold=True)
style_all(cd, 1, last_cd+1, 1, 10+len(sups)); cd.freeze_panes = 'D2'
cd['C1'].comment = Comment('1 = ouvert, 0 = ferme. Modifiable. Par defaut fermes : 24, 25, 26 decembre 2026 et 1er janvier 2027 (comme en 2025).', 'PBT')

# ---------- 7. Commandes 2026 par fournisseur ----------
pattern = collections.defaultdict(collections.Counter)   # (sup, etab) -> weekday -> nb livraisons
for (d, s, e), v in mt.items():
    if D0 <= d <= D1: pattern[(s, e)][d.weekday()] += 1
NEG = []  # (sup, etab, art, unite, ws title, row)
for s in sups:
    for e, nom in ETABS:
        arts = [(k, a) for k, a in order if k[0] == s and k[1] == e and a['alim'] and (len(a['livs']) >= 3 or a['m'] >= 100)]
        if not arts: continue
        wsn = f'Cmd {s[:14]} {nom}'[:31]
        co = wb.create_sheet(wsn)
        # jours de livraison 2026 : jours de semaine observes en 2025 (>=2 fois) ∩ tournee ; si rien, tous les jours de tournee observes au moins 1 fois
        court = len(livdates.get((s, e), ())) < 8
        wds = {wd for wd, n in pattern[(s, e)].items() if (n >= 2 or court) and TOURNEES[s][wd]} or {wd for wd, n in pattern[(s, e)].items() if TOURNEES[s][wd]} or {wd for wd in range(7) if TOURNEES[s][wd]}
        livs = [d for d in jours_cible if d.weekday() in wds and d not in FERMES_2026]
        if livs and livs[0] != E0: livs = [E0] + livs
        co['A1'] = f'COMMANDES PROPOSEES 2026 - {s} - {nom}'; co['A1'].font = F(bold=True, size=12)
        co['A2'] = f"Jours de livraison repris du rythme 2025 : {', '.join(JOURS[w] for w in sorted(wds))}. Quantite = (qte pour 100 plats) x (plats prevus de la livraison jusqu'a la suivante) / 100, arrondie au superieur. Ratios et plats prevus modifiables dans les autres onglets."; co['A2'].font = F(italic=True, color='808080')
        base = ['Article', 'Unite', 'Qte 2025 periode', 'Qte pour 100 plats', 'Total 2026 propose']
        hdr(co, 4, base + [d for d in livs], [44, 7, 11, 11, 12] + [9]*len(livs))
        for j, d in enumerate(livs, 6):
            c = co.cell(row=4, column=j); c.value = d; c.number_format = 'DD/MM'; 
            co.cell(row=3, column=j, value=JOURS[d.weekday()]).alignment = Alignment(horizontal='center')
        plats_col = 'F' if e == 'freddy' else 'H'
        for i, ((_, _, art), a) in enumerate(arts, 5):
            r = ART_ROW[(s, e, art)]
            co.cell(row=i, column=1, value=art); co.cell(row=i, column=2, value=a['unite'])
            co.cell(row=i, column=3, value=f"='Achats 2025 articles'!G{r}").number_format = '#,##0.0'
            co.cell(row=i, column=4, value=f"='Achats 2025 articles'!K{r}").number_format = '#,##0.00'
            co.cell(row=i, column=5, value=f'=SUM(F{i}:{L(5+len(livs))}{i})').number_format = '#,##0'
            co.cell(row=i, column=5).font = F(bold=True)
            for j, d in enumerate(livs, 6):
                nxt = livs[j-5] if j-5 < len(livs) else E1 + dt.timedelta(days=1)
                co.cell(row=i, column=j, value=f"=ROUNDUP($D{i}/100*SUMIFS('Cadencier 2026'!${plats_col}$2:${plats_col}${last_cd},'Cadencier 2026'!$A$2:$A${last_cd},\">=\"&{L(j)}$4,'Cadencier 2026'!$A$2:$A${last_cd},\"<\"&DATE({nxt.year},{nxt.month},{nxt.day})),0)").number_format = '0'
            NEG.append((s, e, art, a['unite'], wsn, i, r))
        style_all(co, 4, 4+len(arts), 1, 5+len(livs)); co.freeze_panes = 'F5'

# ---------- 8. Negociation ----------
ng = wb.create_sheet('Negociation', 2)
hdr(ng, 1, ['Fournisseur', 'Etab', 'Article', 'Unite', 'Qte 2025 periode', 'Montant HT 2025', 'PU moyen 2025', 'Qte 2026 proposee', 'Budget 2026 au PU 2025', 'Prix negocie (a saisir)', 'Economie'], [18, 8, 44, 7, 11, 12, 10, 12, 12, 12, 10])
for i, (s, e, art, u, wsn, row, r) in enumerate(NEG, 2):
    ng.cell(row=i, column=1, value=s); ng.cell(row=i, column=2, value=dict(ETABS)[e]); ng.cell(row=i, column=3, value=art); ng.cell(row=i, column=4, value=u)
    ng.cell(row=i, column=5, value=f"='Achats 2025 articles'!G{r}").number_format = '#,##0.0'
    ng.cell(row=i, column=6, value=f"='Achats 2025 articles'!H{r}").number_format = '#,##0.00'
    ng.cell(row=i, column=7, value=f"='Achats 2025 articles'!I{r}").number_format = '#,##0.00'
    ng.cell(row=i, column=8, value=f"='{wsn}'!E{row}").number_format = '#,##0'
    ng.cell(row=i, column=9, value=f'=H{i}*G{i}').number_format = '#,##0.00'
    c = ng.cell(row=i, column=10); c.fill = INPUT; c.font = BLUE; c.number_format = '#,##0.00'
    ng.cell(row=i, column=11, value=f'=IF(J{i}="","",(G{i}-J{i})*H{i})').number_format = '#,##0.00'
ln = len(NEG) + 1
ng.cell(row=ln+1, column=1, value='TOTAL').font = F(bold=True)
for j in (6, 9, 11): ng.cell(row=ln+1, column=j, value=f'=SUM({L(j)}2:{L(j)}{ln})').number_format = '#,##0.00'
style_all(ng, 1, ln+1, 1, 11); ng.freeze_panes = 'D2'; ng.auto_filter.ref = f'A1:K{ln}'
ng['J1'].comment = Comment('Saisir ici le prix unitaire HT obtenu du fournisseur. L economie se calcule seule.', 'PBT')

for w in wb.worksheets:
    for row in w.iter_rows():
        for c in row:
            if c.font.name != font: c.font = Font(name=font, bold=c.font.bold, italic=c.font.italic, color=c.font.color, size=c.font.size)
wb.save(OUT)
print('ecrit', OUT, '| onglets:', [w.title for w in wb.worksheets])
print('articles base:', len(NEG))
