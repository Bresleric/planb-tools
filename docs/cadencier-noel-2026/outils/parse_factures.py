import re, csv, glob, os, sys, collections, datetime
TXT = sys.argv[1] if len(sys.argv) > 1 else "txt"
OUT = sys.argv[2] if len(sys.argv) > 2 else "lignes_factures.csv"
def num(s):
    if s is None: return None
    s = s.replace(' ','').replace(' ','').replace(',', '.')
    try: return float(s)
    except: return None
def d_ddmmyy(s):
    for fmt in ("%d/%m/%Y","%d/%m/%y","%d-%m-%Y"):
        try: return datetime.datetime.strptime(s, fmt).date().isoformat()
        except: pass
    return None
def etab_of(text):
    t = text.upper()
    if 'TANTE LIESEL' in t or 'BONBAO' in t or 'RUE DES DENTELLES' in t: return 'liesel'
    if 'FREDDY' in t or 'RUE DES MOULINS' in t: return 'freddy'
    return '?'
def supplier_of(fname, text):
    f = fname.lower(); t = text[:3500].upper()
    for k, v in [('SAPAM STRASBOURG','Sapam'),('PROMOCASH','Promocash'),('ESSENTIEL RHF','Essentiel RHF'),('DISTRIBUTION ILLER','Distribution Iller'),('CHOUCROUTEWEBER','Choucroute Weber'),('METRO FRANCE','Metro'),('KOCH','Koch'),('WOLFBERGER','Wolfberger'),('ORANGE','Orange'),('BELLES QUILLES','Nos Belles Quilles'),('ALSABRET','Alsabret'),('BPALC','Banque'),('ZEYSSOLFF','Zeyssolff')]:
        if k in t: return v
    for k, v in [('essentiel','Essentiel RHF'),('sapam','Sapam'),('promocash','Promocash'),('iller','Distribution Iller'),('weber','Choucroute Weber'),('metro','Metro'),('koch','Koch'),('wolfb','Wolfberger'),('quilles','Nos Belles Quilles'),('alsabret','Alsabret'),('zeyssolff','Zeyssolff'),('sieso','Laurent Sieso'),('m&h','Malt et Houblon'),('marx','Marx')]:
        if k in f: return v
    if 'METRO' in t: return 'Metro'
    return 'Inconnu'
rows, stats, unparsed = [], collections.defaultdict(lambda: collections.Counter()), collections.defaultdict(list)
def add(**kw):
    rows.append(kw)
for path in sorted(glob.glob(os.path.join(TXT, "*.txt"))):
    fname = os.path.basename(path)[:-4]
    text = open(path, encoding='utf-8').read()
    lines = [l.rstrip() for l in text.split('\n')]
    sup = supplier_of(fname, text); etab = etab_of(text[:4000])
    inv = None; dinv = None; dliv = None; bl = None
    stats[sup]['fichiers'] += 1
    n0 = len(rows)
    if sup == 'Essentiel RHF':
        m = re.search(r'Facture N°\s*(\S+)', text); inv = m and m.group(1)
        m = re.search(r'\n(\d{2}/\d{2}/\d{4})\s+\w+\s+Page', text); dinv = m and d_ddmmyy(m.group(1))
        for l in lines:
            m = re.search(r'Bon de livraison client\s*:\s*(BL-\d+)\s*:\s*(\d{2}/\d{2}/\d{2})', l)
            if m: bl, dliv = m.group(1), d_ddmmyy(m.group(2)); continue
            m = re.match(r'^(\S+)\s{2,}(.+?)\s{2,}(-?[\d\s]+,\d+)\s+(\S+)\s+(-?[\d\s]*,\d+)\s+(-?[\d\s]*,\d+)\s+(\d+,\d+)%$', l)
            if m:
                add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dliv or dinv, bl=bl, code=m.group(1), designation=m.group(2).strip(), qte=num(m.group(3)), unite=m.group(4), pu_ht=num(m.group(5)), montant_ht=num(m.group(6)), tva=num(m.group(7)))
            elif re.search(r'\d,\d\d\s+\d+,\d+%$', l): unparsed[sup].append(l)
    elif sup == 'Choucroute Weber':
        m = re.search(r'Facture N\s*°\s*(\d+)', text); inv = m and m.group(1)
        m = re.search(r'\n(\d{2}/\d{2}/\d{4})\n', text); dinv = m and d_ddmmyy(m.group(1))
        inzone = False
        for l in lines:
            if l.startswith('Désignation'): inzone = True; continue
            if l.startswith('Page :') or 'Total H.T.' in l and 'Désignation' not in l and inzone and re.search(r'TOTAL|Total HT', l): pass
            m = re.search(r'B\.L\. N°\s*\((\d+)\)\s*Date\s*:\s*(\d{2}/\d{2}/\d{4})', l)
            if m: bl, dliv = m.group(1), d_ddmmyy(m.group(2)); continue
            if not inzone: continue
            m = re.match(r'^(.+?)\s{2,}(-?\d+,\d+)\s+(-?\d+,\d+)\s+(-?\d+,\d+)$', l)
            if m and not l.startswith(('Total','TOTAL','Base','Montant')):
                add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dliv or dinv, bl=bl, code=None, designation=m.group(1).strip(), qte=num(m.group(2)), unite='kg/pc', pu_ht=num(m.group(3)), montant_ht=num(m.group(4)), tva=5.5)
    elif sup == 'Sapam':
        m = re.search(r'Num[Èé]ro\s+(\S+)', text); inv = m and m.group(1)
        m = re.search(r'\bdu (\d{2}/\d{2}/\d{2})\b', text); dinv = m and d_ddmmyy(m.group(1))
        for l in lines:
            m = re.search(r'Notre BL\s+(\d+)\s+du\s+(\d{2}/\d{2}/\d{2})', l)
            if m: bl, dliv = m.group(1), d_ddmmyy(m.group(2)); continue
            m = re.match(r'^\+(\w\w)\s+(.+?)\s+([KPC])((?:\s+[\d.]+){3,7})$', l)
            if m:
                g = m.groups(); unit = {'K':'kg','P':'pce','C':'colis'}[g[2]]
                nums = g[3].split()  # ... qty pu total tva
                tva, total, pu = nums[-1], num(nums[-2]), num(nums[-3])
                qty = num(nums[-4]) if len(nums) >= 4 else None
                if pu and (qty is None or abs(qty*pu - total) > max(0.05, 0.02*total)):
                    qty = round(total/pu, 3)
                add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dliv or dinv, bl=bl, code=g[0], designation=g[1].strip(), qte=qty, unite=unit, pu_ht=pu, montant_ht=total, tva=5.5)
            elif l.startswith('+') and not l.startswith('+ '): unparsed[sup].append(l)
    elif sup == 'Promocash':
        m = re.search(r'\n(\d{6})\nDate\s*:\s*(\d{2}/\d{2}/\d{4})', text)
        if m: inv, dinv = m.group(1), d_ddmmyy(m.group(2))
        else:
            m = re.search(r'Date\s*:\s*(\d{2}/\d{2}/\d{4})', text); dinv = m and d_ddmmyy(m.group(1))
            m = re.search(r'N° Facture\s*:?\s*(\d{6})', text) or re.search(r'\n(\d{6})\n', text); inv = m and m.group(1)
        m = re.search(r'Date Livraison\s*:\s*(\d{2}/\d{2}/\d{4})', text); dliv = m and d_ddmmyy(m.group(1))
        prev = ''
        for idx, l in enumerate(lines):
            m3 = re.match(r'^(\d{6}) (-?[\d\s]+,\d+) (\d+,\d)%(?: [\d,]+)?$', l)
            if m3 and idx+1 < len(lines):
                nx = lines[idx+1]
                m4 = re.match(r'^(.*?)\s*(-?\d+,\d+) (\d+,\d+)(?: (Promo|Offre Cciale|Date Courte|Remise \S+))?\s*$', nx)
                if m4:
                    lib = (prev.strip() + ' ' + m4.group(1).strip()).strip()
                    add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dliv or dinv, bl=None, code=m3.group(1), designation=lib, qte=num(m4.group(2)), unite='kg', pu_ht=num(m4.group(3)), montant_ht=num(m3.group(2)), tva=num(m3.group(3)))
                    prev = l; continue
            m = re.match(r'^(\d{6}) (-?[\d\s]+,\d+) (.+?) (\d+(?:,\d+)?) ([\d\s]+,\d+)(?: (Promo|Offre Cciale|Date Courte|Remise \S+))? (\d+,\d)%', l)
            if m:
                add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dliv or dinv, bl=None, code=m.group(1), designation=m.group(3).strip(), qte=num(m.group(4)), unite=('kg' if m.group(3).strip().upper().startswith('KG') else 'colis'), pu_ht=num(m.group(5)), montant_ht=num(m.group(2)), tva=num(m.group(7)))
            else:
                m = re.match(r'^(\d{6}) (-?[\d\s]+,\d+) (\d+(?:,\d+)?) ([\d\s]+,\d+)(?: (Promo|Offre Cciale|Date Courte|Remise \S+))? (\d+,\d)%', l)
                if m:
                    add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dliv or dinv, bl=None, code=m.group(1), designation=prev.strip(), qte=num(m.group(3)), unite='colis', pu_ht=num(m.group(4)), montant_ht=num(m.group(2)), tva=num(m.group(6)))
                elif re.match(r'^\d{6} ', l) and '%' in l: unparsed[sup].append(l)
            prev = l
    elif sup == 'Distribution Iller':
        m = re.search(r'Réf\.\s*:\s*(FA\S+)', text); inv = m and m.group(1)
        m = re.search(r'Date facturation\s*:\s*(\d{2}/\d{2}/\d{4})', text); dinv = m and d_ddmmyy(m.group(1))
        pending = None
        for l in lines:
            m = re.match(r'^(\d{6}) - (.+?)\s{2,}(\d+,\d+)%\s+(-?[\d\s]+,\d+)\s+(-?[\d.]+)\s+(-?[\d\s]+,\d+)$', l)
            if m:
                pending = dict(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dinv, bl=None, code=m.group(1), designation=m.group(2).strip(), qte=num(m.group(5)), unite='', pu_ht=num(m.group(4)), montant_ht=num(m.group(6)), tva=num(m.group(3)))
                rows.append(pending); continue
            if pending and re.match(r'^(KILO|PIECE|PIÈCE|BARQUE|BARQUETTE|CARTON|SACHET|UNITE|UNITÉ|TTE|LITRE|POT|SEAU|BOITE)', l.strip()):
                u = l.strip(); pending['unite'] = {'KILO':'kg','BARQUE':'barquette','TTE':'barquette'}.get(u, u.lower())
                if u not in ('BARQUE',): pending = None
            elif re.match(r'^\d{6} - ', l) and '%' in l: unparsed[sup].append(l)
    elif sup == 'Metro':
        m = re.search(r'Date facture\s*:\s*(\d{2}-\d{2}-\d{4})', text); dinv = m and d_ddmmyy(m.group(1))
        m = re.search(r'Nº FACTURE\s*(\S+)', text); inv = m and m.group(1)
        merged = []; i = 0
        while i < len(lines):
            l = lines[i]
            if re.match(r'^\d{8,13} \d{7} ', l) and not re.search(r' [A-Z](?: P)?(?: \d+)?$', l) and i+1 < len(lines) and re.match(r'^[\d, ]+[A-Z](?: P)?(?: \d+)?$', lines[i+1].strip()):
                merged.append(l + ' ' + lines[i+1].strip()); i += 2; continue
            merged.append(l); i += 1
        for l in merged:
            m = re.match(r'^(\d{8,13}) (\d{7}) (.+?) ((?:-?\d+,\d{3} )?)(-?\d+,\d{3}) (\d+) (\d+ )?(-?\d+,\d{2}) ([A-Z])(?: P)?(?: \d+)?$', l)
            if m:
                poids = num(m.group(4).strip()) if m.group(4).strip() else None
                qte = num(m.group(6)); pu = num(m.group(5)); mt = num(m.group(8))
                add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dinv, bl=None, code=m.group(2), designation=m.group(3).strip(), qte=poids if poids else qte, unite='kg' if poids else 'pce', pu_ht=pu, montant_ht=mt, tva=m.group(9))
            elif re.match(r'^\d{13} \d{7} ', l): unparsed[sup].append(l)
    elif sup == 'Koch':
        m = re.search(r'\n(\d{2}/\d{2}/\d{4})\s+(\d{8})\s+CONCL', text)
        if m: dinv, inv = d_ddmmyy(m.group(1)), m.group(2)
        m = re.search(r'Livré à\s+(.+)', text); etab = etab_of(m.group(1)) if m else etab
        for l in lines:
            m = re.search(r'Notre BL N°\s*(\d{2}/\d{2}/\d{4})\s+(\d+)', l)
            if m: dliv, bl = d_ddmmyy(m.group(1)), m.group(2); continue
            m = re.match(r'^(\S+)\s{2,}(.+?)\s{2,}(-?[\d\s]+,\d{3})\s+([A-Z]{2})\s+\d\s+([\d\s]+,\d{3})(?:\s+PR)?(?:\s+(\d+,\d{2}))?\s+(-?[\d\s]+,\d{2})$', l)
            if m:
                u = {'KG':'kg','PC':'pce','BQ':'barquette','ST':'sachet','LT':'L','CT':'carton','BT':'bouteille','SE':'seau','SA':'sac','BO':'boite'}.get(m.group(4), m.group(4).lower())
                add(fournisseur=sup, etablissement=etab, fichier=fname, facture=inv, date_facture=dinv, date_livraison=dliv or dinv, bl=bl, code=m.group(1), designation=m.group(2).strip(), qte=num(m.group(3)), unite=u, pu_ht=num(m.group(5)), montant_ht=num(m.group(7)), tva=5.5)
            elif re.match(r'^\S+\s{2,}.+\d,\d{3}\s+[A-Z]{2}\s+\d\s', l): unparsed[sup].append(l)
    else:
        stats[sup]['non traites'] += 1; continue
    n = len(rows) - n0
    stats[sup]['lignes'] += n
    if n == 0: stats[sup]['fichiers sans ligne'] += 1
    if not dinv: stats[sup]['sans date'] += 1
    if etab == '?': stats[sup]['etab inconnu'] += 1
# dedoublonnage par (fournisseur, facture)
seen = {}; dedup = []
for r in rows:
    k = (r['fournisseur'], r['facture'])
    if k in seen and seen[k] != r['fichier']: continue
    seen[k] = r['fichier']; dedup.append(r)
with open(OUT, 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(dedup[0].keys())); w.writeheader(); w.writerows(dedup)
print(f"lignes: {len(rows)} -> apres dedoublonnage factures: {len(dedup)}")
for s, c in sorted(stats.items()): print(f"  {s:20} {dict(c)}")
for s, ls in unparsed.items():
    print(f"\n-- non lues {s} ({len(ls)}):"); [print("    ", l[:150]) for l in ls[:8]]
