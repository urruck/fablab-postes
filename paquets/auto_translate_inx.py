#!/usr/bin/env python3
"""
Auto-traduction des chaînes anglaises restantes dans les .inx MightyScape
via MyMemory (API gratuite, ~5000 mots/jour).
Usage: python3 auto_translate_inx.py <extensions_dir>
"""

import os, re, sys, time, json
from deep_translator import MyMemoryTranslator

EXTENSIONS_DIR = sys.argv[1] if len(sys.argv) > 1 else "."

# ─── Détecteur : contient-il encore de l'anglais ? ───────────────────────────
ENGLISH = re.compile(
    r'\b(the |a |an |of |in |on |at |by |for |to |with |and |or |not |is |are |'
    r'use|add |set |get |new |all |from|this|that|when|has |show|hide|file|type '
    r'|size |width |height |angle |radius |scale |offset |color |count |step |'
    r'mode |output |input |select |remove |create |generate |move |rotate |flip |'
    r'apply |draw |fill |stroke |line |curve |node |group |layer |object |text |'
    r'font |align |center |none |auto |box |value |range |unit |point |side |'
    r'edge |face |corner |base |inner |outer |slot |hole |depth |length |distance |'
    r'position |order |random |normal |reverse |cut |split |join |merge |export |'
    r'import |reset |test |sample |preview |render |zoom |fit |trim |extend |'
    r'shrink |expand |rotate |mirror |snap |sort |search |clear |clean |purge |'
    r'optimize |simplify |smooth |round |open |closed |fixed |free |loop |repeat |'
    r'each |every |between |before |after |custom |default |global |local |'
    r'relative |absolute |keep |original |image |canvas |table |cells |column |'
    r'row |tooth |teeth |polygon |sides |grid |rings |square |pattern |tower |'
    r'mountain |valley |crease |hinge |vertex |vertices |attach |slot |lid |lids |'
    r'tabs |tab |flange |sealing |closure |mark |marks |stock )\b',
    re.I
)

# Exclure les noms de modèles boxes.py (PascalCase ou snake_case sans espaces)
MODEL_NAME = re.compile(r'^[A-Z][a-zA-Z0-9]+$|^[a-z_]+$|^[A-Z_]+$')

# Exclure les identifiants techniques
TECHNICAL = re.compile(r'[{}<>\[\]@#$%^&*|\\\/]|^[a-z][a-zA-Z]+[A-Z]')

def needs_translation(s):
    if not s or len(s) < 3:
        return False
    if TECHNICAL.search(s):
        return False
    if MODEL_NAME.match(s.strip()) and ' ' not in s.strip():
        return False
    return bool(ENGLISH.search(s))

# ─── Collecte de toutes les chaînes uniques à traduire ───────────────────────
def extract_strings(extensions_dir):
    attrs = re.compile(r'gui-text="([^"]+)"|gui-description="([^"]+)"')
    strings = set()
    for root, dirs, files in os.walk(extensions_dir):
        for fname in files:
            if not fname.endswith('.inx'):
                continue
            path = os.path.join(root, fname)
            try:
                content = open(path, encoding='utf-8', errors='replace').read()
            except Exception:
                continue
            for m in attrs.finditer(content):
                for g in m.groups():
                    if g and needs_translation(g):
                        strings.add(g)
    return sorted(strings)

# ─── Traduction par batch ─────────────────────────────────────────────────────
def translate_batch(strings, cache_file='/tmp/translations_cache.json'):
    # Charger le cache existant
    cache = {}
    if os.path.exists(cache_file):
        with open(cache_file) as f:
            cache = json.load(f)

    translator = MyMemoryTranslator(source='en-US', target='fr-FR')
    new_translations = {}

    to_translate = [s for s in strings if s not in cache]
    print(f"Chaînes à traduire : {len(to_translate)} (cache : {len(cache)})")

    for i, s in enumerate(to_translate):
        # Limiter à 500 chars (limite MyMemory)
        if len(s) > 490:
            print(f"  [SKIP trop long] {s[:60]}...")
            continue
        try:
            result = translator.translate(s)
            if result and result != s:
                new_translations[s] = result
                cache[s] = result
                print(f"  [{i+1}/{len(to_translate)}] {s!r:50} → {result!r}")
            else:
                print(f"  [{i+1}/{len(to_translate)}] [INCHANGÉ] {s!r}")
        except Exception as e:
            print(f"  [{i+1}/{len(to_translate)}] [ERREUR] {s!r}: {e}")

        # Sauvegarder le cache toutes les 20 traductions
        if (i + 1) % 20 == 0:
            with open(cache_file, 'w') as f:
                json.dump(cache, f, ensure_ascii=False, indent=2)

        time.sleep(0.3)  # Respecter la limite de taux

    # Sauvegarde finale
    with open(cache_file, 'w') as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

    print(f"\nNouvelles traductions : {len(new_translations)}")
    return cache

# ─── Application des traductions aux fichiers ────────────────────────────────
def apply_translations(extensions_dir, translations):
    attrs_pat = re.compile(r'(gui-text|gui-description)="([^"]+)"')
    files_modified = 0
    replacements_total = 0

    for root, dirs, files in os.walk(extensions_dir):
        for fname in files:
            if not fname.endswith('.inx'):
                continue
            path = os.path.join(root, fname)
            try:
                content = open(path, encoding='utf-8', errors='replace').read()
            except Exception:
                continue

            original = content

            def replace_attr(m):
                attr_name = m.group(1)
                value = m.group(2)
                if value in translations:
                    return f'{attr_name}="{translations[value]}"'
                return m.group(0)

            content = attrs_pat.sub(replace_attr, content)

            if content != original:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
                files_modified += 1
                replacements_total += content.count('\n') - original.count('\n') + 1

    print(f"Fichiers modifiés : {files_modified}")

# ─── Post-corrections manuelles pour les cas mal traduits ────────────────────
MANUAL_FIXES = {
    # Cas courants mal traduits par MyMemory
    "Mountain creases color:": "Couleur des plis montagne :",
    "Valley creases color:": "Couleur des plis vallée :",
    "Bord color:": "Couleur des bords :",
    "Vertices' color:": "Couleur des sommets :",
    "the Couvercle": "le Couvercle",
    "Simulation mode": "Mode simulation",
    "Simplify geometry": "Simplifier la géométrie",
    "Parallelize Simplify geometry": "Simplifier la géométrie (parallèle)",
    "Activer point display in viewer": "Activer l'affichage des points",
    "Auto-convert low-level strokes to paths": "Convertir automatiquement les tracés en chemins",
    "Utiliser style of first element in layer": "Utiliser le style du premier élément du calque",
    "Trait width of tooling lines (px)": "Épaisseur des lignes d'usinage (px)",
    "Trait width of trajectory lines (px)": "Épaisseur des lignes de trajectoire (px)",
    "Hinges and HingePins": "Charnières et axes de charnière",
    "Slide-on Lids": "Couvercles coulissants",
    "Click-on Lids": "Couvercles à clipser",
    "A - width:": "A - largeur :",
    "L - length:": "L - longueur :",
    "H - height:": "H - hauteur :",
    "Space Between Parts": "Espace entre les pièces",
    "Nombre of cells": "Nombre de cellules",
    "Hauteur of base": "Hauteur de la base",
    "Then rotate around:": "Puis tourner autour de :",
    "Nombre of polygon sides": "Nombre de côtés du polygone",
    "Add base slots?": "Ajouter des encoches de base ?",
    "Hauteur of base slot": "Hauteur des encoches de base",
    "Largeur of base slow": "Largeur des encoches de base",
    "Add slots between cells?": "Ajouter des encoches entre les cellules ?",
    "Distance between cells": "Distance entre les cellules",
    "Hauteur of slots between cells": "Hauteur des encoches entre cellules",
    "Largeur of slots between cells": "Largeur des encoches entre cellules",
    "Redimensionner the canvas to the imported drawing's bounding box": "Redimensionner le canevas au dessin importé",
    "Add extra border around fitted canvas": "Ajouter une bordure supplémentaire",
    "Longueur of elements": "Longueur des éléments",
    "C - Haut side sealing flange:": "C - Bride d'étanchéité côté haut :",
    "T - Haut side closure tabs:": "T - Languettes de fermeture côté haut :",
    "Nombre of teeth": "Nombre de dents",
    "Nombre of Ligne Segments:": "Nombre de segments de ligne :",
    "Keep the table original height": "Conserver la hauteur originale du tableau",
    "Nombre of sides of polygon": "Nombre de côtés du polygone",
    "Couper dash + gap length": "Longueur du tiret + écart",
    "Largeur of cut strokes": "Largeur des traits de coupe",
    "Couper creases color:": "Couleur des plis de découpe :",
    "Manuel scale factor": "Facteur d'échelle manuel",
    "Trait color": "Couleur du trait",
    "Keep original image on canvas": "Conserver l'image originale",
    "Supprimer control object": "Supprimer l'objet de contrôle",
    "GCode Importer Mode": "Mode import GCode",
    "Included (full) angle, degrees": "Angle total (degrés)",
    "Z value at top of stock": "Valeur Z au sommet du brut",
    "Courbe interpolation step size": "Pas d'interpolation de courbe",
    "Chemin width / tool diameter": "Largeur du chemin / diamètre outil",
    "Coin radius": "Rayon de coin",
    "Inverser order": "Inverser l'ordre",
    "fit axis lenght to compartments": "Ajuster l'axe aux compartiments",
    "Type of Kresling tower": "Type de tour Kresling",
    "Add attachments?": "Ajouter des attaches ?",
    "Centre base slots?": "Centrer les encoches de base ?",
    "Externe base vertices?": "Sommets externes de base ?",
    "Other base vertices?": "Autres sommets de base ?",
    "Externe radius vertices?": "Sommets externes du rayon ?",
    "Interne radius vertices?": "Sommets internes du rayon ?",
    "Longueur of grid square": "Longueur du carré de grille",
    "Nombre of rings": "Nombre d'anneaux",
    "Nombre of columns": "Nombre de colonnes",
    "Orthographic angle": "Angle orthographique",
    "Police size:": "Taille de police :",
    "Dot size:": "Taille du point :",
    "Debugging information output": "Afficher les informations de débogage",
    "Convertir Texte to Paths": "Convertir le texte en chemins",
    "Bordure offset units": "Unités de décalage de bordure",
    "P - Largeur glue tab": "P - Largeur de la languette de collage",
    "Rayon of bigger polygon": "Rayon du plus grand polygone",
    "Rapport small radius/big radius": "Rapport petit rayon/grand rayon",
    "Angle of superior cone (alpha1)": "Angle du cône supérieur (alpha1)",
    "Angle of inferior cone (alpha2)": "Angle du cône inférieur (alpha2)",
    "Hauteur of superior cone (h1)": "Hauteur du cône supérieur (h1)",
    "Hauteur of inferior cone (h2)": "Hauteur du cône inférieur (h2)",
    "Longueur (percentage of label line length):": "Longueur (% de la ligne de repère) :",
    "Dessiner every x lines:": "Dessiner toutes les x lignes :",
    "Measure value:": "Valeur mesurée :",
    "Measure type:": "Type de mesure :",
    "Parameter type:": "Type de paramètre :",
    "Angle ratio:": "Rapport d'angle :",
    "Angle between a and l": "Angle entre a et l",
    "Rotation angle (degree)": "Angle de rotation (degrés)",
    "Base slot position:": "Position des encoches de base :",
    "Milieu slot position:": "Position des encoches médianes :",
    "Type of pattern:": "Type de motif :",
    "Type:": "Type :",
    "Mode:": "Mode :",
    "Mode": "Mode",
    "Type": "Type",
    "size": "taille",
}

# ─── Main ─────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print(f"Scan de {EXTENSIONS_DIR}...")
    strings = extract_strings(EXTENSIONS_DIR)
    print(f"Chaînes anglaises détectées : {len(strings)}")

    # Appliquer d'abord les corrections manuelles
    print("\nApplication des corrections manuelles...")
    apply_translations(EXTENSIONS_DIR, MANUAL_FIXES)

    # Puis auto-traduction du reste
    print("\nAuto-traduction via MyMemory...")
    translations = translate_batch(strings)

    print("\nApplication des traductions auto...")
    apply_translations(EXTENSIONS_DIR, translations)

    print("\nTerminé !")
