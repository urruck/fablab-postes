#!/usr/bin/env python3
"""
Correction des patterns anglais résiduels dans les .inx MightyScape.
Applique des substitutions regex ciblées sur les valeurs d'attributs.
"""
import os, re, sys

EXTENSIONS_DIR = sys.argv[1] if len(sys.argv) > 1 else "."

# ─── Remplacements de phrases complètes (exact match dans attributs) ──────────
EXACT = {
    # Patterns "X of Y" résiduels
    "Hauteur of box": "Hauteur de la boîte",
    "Hauteur of image": "Hauteur de l'image",
    "Hauteur of slots (%)": "Hauteur des encoches (%)",
    "Hauteur of the Arc(units)": "Hauteur de l'arc (unités)",
    "Hauteur of the can in mm": "Hauteur de la boîte en mm",
    "Hauteur of window": "Hauteur de la fenêtre",
    "Diameter of final disk": "Diamètre du disque final",
    "Diameter of the can in mm": "Diamètre de la boîte en mm",
    "Épaisseur of sheets to find": "Épaisseur des feuilles à trouver",
    "Épaisseur of trigger ring": "Épaisseur de l'anneau de déclenchement",
    "Encastrement size computed from box dimensions": "Taille d'encastrement calculée",
    "Encastrement size for joints in X direction": "Taille d'encastrement pour les joints en X",
    "Encastrement size for joints in Y direction": "Taille d'encastrement pour les joints en Y",
    "Encastrement size for joints in Z direction": "Taille d'encastrement pour les joints en Z",
    "No of Rangées:": "Nombre de rangées :",
    "Nombre of nodes:": "Nombre de nœuds :",
    "Taille of vertices (%)": "Taille des sommets (%)",
    "Taille of specks": "Taille des taches",
    "Taille of scratches": "Taille des égratignures",
    "Taille of objects (scale factor)": "Taille des objets (facteur d'échelle)",
    "Taille of chips": "Taille des copeaux",
    "Taille of a blob": "Taille d'un blob",
    "Unité of Measurement": "Unité de mesure",
    "Unités for following dimensions": "Unités pour les dimensions suivantes",
    "Unité for width/height": "Unité pour largeur/hauteur",
    "Unité for values:": "Unité pour les valeurs :",
    "Sort of hatches:": "Type de hachures :",
    "Sortie image size (px)": "Taille de l'image de sortie (px)",
    "Smoothing of polylines": "Lissage des polylignes",
    "Slope of the wall:": "Pente de la paroi :",
    # Patterns "X and Y"
    "Haut and Bas Design": "Design haut et bas",
    "Haut and bottom?": "Haut et bas ?",
    "Sine and Lace": "Sinus et lacet",
    "Swap links with dashes": "Échanger les liens avec des tirets",
    # Patterns "Keep X"
    "Keep original objects": "Conserver les objets originaux",
    "Keep selected elements": "Conserver les éléments sélectionnés",
    "Keep the table original height": "Conserver la hauteur originale du tableau",
    "Keep original image on canvas": "Conserver l'image originale",
    "Keep all listed entity types (override filter selection)": "Conserver tous les types d'entités listés",
    "Keep aspect ratio": "Conserver le ratio d'aspect",
    # "Add X"
    "Add chamfer radius [mm]": "Ajouter un rayon de chanfrein [mm]",
    "Add width increase*": "Augmenter la largeur*",
    # "From X"
    "From bounding box": "Depuis le cadre englobant",
    "From corners": "Depuis les coins",
    "From nodes": "Depuis les nœuds",
    "From the middle": "Depuis le centre",
    # Patterns "Type of X"
    "Type of template": "Type de gabarit",
    "Type of line reducing": "Type de réduction de ligne",
    "Type of Hypar": "Type d'hyperboloïde",
    # Patterns "Mode X"
    "Mode simulation": "Mode simulation",
    "Mode import GCode": "Mode import GCode",
    # 3D rotate
    "3D-Rotate X-Axis [deg]": "Rotation 3D axe X [°]",
    "3D-Rotate Y-Axis [deg]": "Rotation 3D axe Y [°]",
    "3D-Rotate Z-Axis [deg]": "Rotation 3D axe Z [°]",
    # Divers
    "color vectorization": "Vectorisation couleur",
    "Dashes for cut/coplanar lines": "Tirets pour lignes coplanaires",
    "Décalage from object (all directions)": "Décalage depuis l'objet (toutes directions)",
    "Dessiner pitch circle (for meshing)": "Dessiner le cercle primitif (pour l'engrènement)",
    "Digits for rounding": "Chiffres pour l'arrondi",
    "Dimples instead of tight fit": "Emboîtement souple au lieu de serré",
    "Do not create output path(s) (cosmetic style only)": "Ne pas créer de chemin de sortie (style cosmétique)",
    "draw svg:path instead svg:circle elements": "Dessiner svg:path au lieu d'éléments svg:circle",
    "Elbow height - from wrist to elbow": "Hauteur du coude - du poignet au coude",
    "Entrée the new height:": "Saisir la nouvelle hauteur :",
    "Entrée the new height of the table:": "Saisir la nouvelle hauteur du tableau :",
    "Entrée the new width:": "Saisir la nouvelle largeur :",
    "Entrée the new width of the table:": "Saisir la nouvelle largeur du tableau :",
    "Epsilon for collinear line filter": "Epsilon pour le filtre de lignes colinéaires",
    "Equalize circle radius of similar length": "Égaliser le rayon des cercles de longueur similaire",
    "Equalize segments of similar length": "Égaliser les segments de longueur similaire",
    "Exporter file format:": "Format de fichier d'export :",
    "Extra notch on corner of horizontal strips": "Encoche supplémentaire aux coins horizontaux",
    "Extra notch on corner of vertical strip": "Encoche supplémentaire aux coins verticaux",
    "Fanned fret style (Treble and Bass scale lengths)": "Style de frettes en éventail (longueurs aigu et grave)",
    "Fermer loops (start/end of the same path)": "Fermer les boucles (début/fin du même chemin)",
    "Fermer subpaths where start and end node have a distance of less than": "Fermer les sous-chemins si la distance début/fin est inférieure à",
    "Filtre by number of tones in a scale.": "Filtrer par nombre de tons dans une gamme.",
    "Filtre entities with ezdxf (recommended if you use sk1 UniConverter)": "Filtrer les entités avec ezdxf",
    "Find and connect nearby facets. Correct bad facets": "Trouver et connecter les facettes proches. Corriger les mauvaises facettes",
    "Fusionner output PDF files into one PDF file": "Fusionner les fichiers PDF de sortie en un seul",
    "Générer and open debug file": "Générer et ouvrir le fichier de débogage",
    "Générer labels for edges": "Générer les étiquettes pour les arêtes",
    "Générer optimized set of parameters": "Générer un jeu de paramètres optimisé",
    "Grouper paths with the generated text elements": "Grouper les chemins avec les éléments de texte générés",
    "Groups and layers": "Groupes et calques",
    "Half hexes at top and bottom": "Demi-hexagones en haut et en bas",
    "Handling of dedicated style attributes": "Gestion des attributs de style dédiés",
    "Ignore these and use 'Haut' options": "Ignorer et utiliser les options 'Haut'",
    "Ignore these settings and use export hints": "Ignorer et utiliser les conseils d'export",
    "Importer file units": "Unités du fichier importé",
    "Imprimer length, pattern and filtering information/errors": "Afficher les informations de longueur, motif et filtrage",
    "Inclure checking each path against itself.": "Inclure la vérification de chaque chemin sur lui-même.",
    "Inclure Image and Distortion template": "Inclure le gabarit Image et Distorsion",
    "Initial offset from original path": "Décalage initial depuis le chemin original",
    "Initial tolerance to use for nearby check": "Tolérance initiale pour la vérification de proximité",
    "Instantiation of multiple objects": "Instanciation de plusieurs objets",
    "Interpolate nodes of segments with total length less than specified length": "Interpoler les nœuds des segments inférieurs à la longueur spécifiée",
    "Inverse (For chamfer and round)": "Inverse (pour chanfrein et arrondi)",
    "Inverser lid notch pattern (this will create a lid without sideways support)": "Inverser le motif d'encoche du couvercle (sans support latéral)",
    "Inverser the directions of all facets and normals": "Inverser la direction de toutes les facettes et normales",
    "Joindre end nodes of separate subpaths where distance less than": "Joindre les nœuds finaux des sous-chemins séparés si distance inférieure à",
    "Joindre Paths / Créer Tabs And Dimples": "Joindre les chemins / Créer languettes et emboîtements",
    "Journal file name": "Nom du fichier journal",
    "Afficher path id": "Afficher l'ID du chemin",
    "Approximation Tolérance (+-unit) [tip, stay between 10^-4 and 1]": "Tolérance d'approximation (±unité) [rester entre 10^-4 et 1]",
    "Décalage from object (all directions)": "Décalage depuis l'objet (toutes directions)",
    "XY Décalage (mm) from top left corner": "Décalage XY (mm) depuis le coin haut-gauche",
    "What to do with collinear overlapping lines?": "Que faire avec les lignes colinéaires superposées ?",
    "vpypetools Free Mode Entries": "Entrées mode libre vpypetools",
    "Utiliser style from first selected": "Utiliser le style du premier sélectionné",
    "Utiliser machine size (else use symmetric border)": "Utiliser la taille de la machine (sinon bordure symétrique)",
    "Utiliser dash style for dividers": "Utiliser le style de tiret pour les séparateurs",
    "Rotate group by an additional angle of 180 degrees": "Rotation du groupe de 180 degrés supplémentaires",
    "thickness of material": "Épaisseur du matériau",
    "The width of the cell:": "La largeur de la cellule :",
    "The number of rows to add:": "Le nombre de rangées à ajouter :",
    "The number of rows:": "Le nombre de rangées :",
    "The number of columns to add:": "Le nombre de colonnes à ajouter :",
    "The number of columns:": "Le nombre de colonnes :",
    "The height of the cell:": "La hauteur de la cellule :",
    "The font size:": "La taille de la police :",
    "Texte color ": "Couleur du texte ",
    "Trait color source": "Source de la couleur du trait",
    "Skip ODA conversion from DXF to DXF (keep input as is)": "Ignorer la conversion ODA DXF vers DXF",
    "Seulement create a module": "Créer seulement un module",
    "Shifting for each piece (%)": "Décalage pour chaque pièce (%)",
    "Shift grid to side and wrap": "Décaler la grille sur le côté et enrouler",
    "shrink circles for cutting": "Réduire les cercles pour la découpe",
    "Simplify center (probably not suited for odd number of sides)": "Simplifier le centre (pas adapté pour un nombre impair de côtés)",
    "Support concavity and holes": "Prendre en charge la concavité et les trous",
    "Supprimer styles from groups": "Supprimer les styles des groupes",
    "Supprimer rotation center object from aligned group": "Supprimer l'objet de centre de rotation du groupe",
    "Supprimer fill and define stroke": "Supprimer le remplissage et définir le contour",
    "ezdxf output version": "Version de sortie ezdxf",
    "GCode Importer Mode": "Mode d'importation GCode",
    "Included (full) angle, degrees": "Angle total inclus (degrés)",
    "Z value at top of stock": "Valeur Z au sommet du brut",
    "Do not create output path(s) (cosmetic style only)": "Ne pas créer de chemin de sortie (style cosmétique seulement)",
}

# ─── Substitutions regex (appliquées dans l'ordre) ────────────────────────────
REGEX_SUBS = [
    # "X of Y" → "X de Y" (où X est un mot français)
    (re.compile(r'\b(Hauteur|Largeur|Longueur|Nombre|Rayon|Épaisseur|Taille|Diamètre|Rapport|Vitesse|Durée|Profondeur|Distance|Angle|Position|Niveau|Valeur|Courbe|Cercle|Point|Centre|Bord|Surface|Volume|Espace|Pas|Intervalle|Décalage|Écart)\s+of\s+', re.I),
     lambda m: m.group(1) + ' de '),
    # " of the " → " du "
    (re.compile(r'\s+of\s+the\s+', re.I), ' du '),
    # " of a " → " d'un "
    (re.compile(r'\s+of\s+a\s+', re.I), " d'un "),
    # " of " restant → " de "
    (re.compile(r'\s+of\s+'), ' de '),
    # " and " → " et "
    (re.compile(r'\s+and\s+', re.I), ' et '),
    # " for " → " pour "
    (re.compile(r'\s+for\s+', re.I), ' pour '),
    # " from " → " depuis "
    (re.compile(r'\s+from\s+', re.I), ' depuis '),
    # " with " → " avec "
    (re.compile(r'\s+with\s+', re.I), ' avec '),
    # " in " → " dans " (prudent - seulement entre mots)
    (re.compile(r'\s+in\s+', re.I), ' dans '),
    # " the " → " le " (approximatif mais mieux que rien)
    (re.compile(r'\s+the\s+', re.I), ' le '),
    # " at " → " à "
    (re.compile(r'\s+at\s+', re.I), ' à '),
    # " by " → " par "
    (re.compile(r'\s+by\s+', re.I), ' par '),
    # " to " → " pour " (contextuel - "à" ou "pour")
    (re.compile(r'\s+to\s+', re.I), ' vers '),
    # "Keep " en début → "Conserver "
    (re.compile(r'^Keep\s+', re.I), 'Conserver '),
    # "Add " en début → "Ajouter "
    (re.compile(r'^Add\s+', re.I), 'Ajouter '),
    # "Show " en début → "Afficher "
    (re.compile(r'^Show\s+', re.I), 'Afficher '),
    # "Use " en début → "Utiliser "
    (re.compile(r'^Use\s+', re.I), 'Utiliser '),
    # "Set " en début → "Définir "
    (re.compile(r'^Set\s+', re.I), 'Définir '),
    # "Create " en début → "Créer "
    (re.compile(r'^Create\s+', re.I), 'Créer '),
    # "Generate " en début → "Générer "
    (re.compile(r'^Generate\s+', re.I), 'Générer '),
    # "Remove " en début → "Supprimer "
    (re.compile(r'^Remove\s+', re.I), 'Supprimer '),
    # "Draw " en début → "Dessiner "
    (re.compile(r'^Draw\s+', re.I), 'Dessiner '),
    # "Export " en début → "Exporter "
    (re.compile(r'^Export\s+', re.I), 'Exporter '),
    # "Import " en début → "Importer "
    (re.compile(r'^Import\s+', re.I), 'Importer '),
    # "Convert " en début → "Convertir "
    (re.compile(r'^Convert\s+', re.I), 'Convertir '),
    # "Enable " en début → "Activer "
    (re.compile(r'^Enable\s+', re.I), 'Activer '),
    # "Disable " en début → "Désactiver "
    (re.compile(r'^Disable\s+', re.I), 'Désactiver '),
    # " size" en fin → " taille"
    (re.compile(r'\bsize\b', re.I), 'taille'),
    # " color" seul → " couleur"
    (re.compile(r'\bcolor\b', re.I), 'couleur'),
    # " width" → " largeur"
    (re.compile(r'\bwidth\b', re.I), 'largeur'),
    # " height" → " hauteur"
    (re.compile(r'\bheight\b', re.I), 'hauteur'),
    # " length" → " longueur"
    (re.compile(r'\blength\b', re.I), 'longueur'),
    # " depth" → " profondeur"
    (re.compile(r'\bdepth\b', re.I), 'profondeur'),
    # " radius" → " rayon"
    (re.compile(r'\bradius\b', re.I), 'rayon'),
    # " distance" → " distance" (même)
    # " angle" → " angle" (même)
    # " path" → " chemin"
    (re.compile(r'\bpath\b', re.I), 'chemin'),
    # " layer" → " calque"
    (re.compile(r'\blayer\b', re.I), 'calque'),
    # " type" → " type" (même)
    # " mode" → " mode" (même)
    # " output" → " sortie"
    (re.compile(r'\boutput\b', re.I), 'sortie'),
    # " input" → " entrée"
    (re.compile(r'\binput\b', re.I), 'entrée'),
    # " file" → " fichier"
    (re.compile(r'\bfile\b', re.I), 'fichier'),
    # " step" → " pas"
    (re.compile(r'\bstep\b', re.I), 'pas'),
    # " count" → " nombre"
    (re.compile(r'\bcount\b', re.I), 'nombre'),
    # " offset" → " décalage"
    (re.compile(r'\boffset\b', re.I), 'décalage'),
    # " scale" → " échelle"
    (re.compile(r'\bscale\b', re.I), 'échelle'),
    # " nodes" → " nœuds"
    (re.compile(r'\bnodes\b', re.I), 'nœuds'),
    # " node" → " nœud"
    (re.compile(r'\bnode\b', re.I), 'nœud'),
    # " corner" → " coin"
    (re.compile(r'\bcorner\b', re.I), 'coin'),
    # " corners" → " coins"
    (re.compile(r'\bcorners\b', re.I), 'coins'),
    # " edge" → " arête"
    (re.compile(r'\bedge\b', re.I), 'arête'),
    # " edges" → " arêtes"
    (re.compile(r'\bedges\b', re.I), 'arêtes'),
    # " stroke" → " contour"
    (re.compile(r'\bstroke\b', re.I), 'contour'),
    # " fill" → " remplissage"
    (re.compile(r'\bfill\b', re.I), 'remplissage'),
    # " slot" → " encoche"
    (re.compile(r'\bslot\b', re.I), 'encoche'),
    # " slots" → " encoches"
    (re.compile(r'\bslots\b', re.I), 'encoches'),
    # " hole" → " trou"
    (re.compile(r'\bhole\b', re.I), 'trou'),
    # " holes" → " trous"
    (re.compile(r'\bholes\b', re.I), 'trous'),
    # " pattern" → " motif"
    (re.compile(r'\bpattern\b', re.I), 'motif'),
    # " grid" → " grille"
    (re.compile(r'\bgrid\b', re.I), 'grille'),
    # " sides" → " côtés"
    (re.compile(r'\bsides\b', re.I), 'côtés'),
    # " side" → " côté"
    (re.compile(r'\bside\b', re.I), 'côté'),
    # " object" → " objet"
    (re.compile(r'\bobject\b', re.I), 'objet'),
    # " objects" → " objets"
    (re.compile(r'\bobjects\b', re.I), 'objets'),
    # " element" → " élément"
    (re.compile(r'\belement\b', re.I), 'élément'),
    # " elements" → " éléments"
    (re.compile(r'\belements\b', re.I), 'éléments'),
    # " teeth" → " dents"
    (re.compile(r'\bteeth\b', re.I), 'dents'),
    # " tooth" → " dent"
    (re.compile(r'\btooth\b', re.I), 'dent'),
    # " ring" → " anneau"
    (re.compile(r'\bring\b', re.I), 'anneau'),
    # " rings" → " anneaux"
    (re.compile(r'\brings\b', re.I), 'anneaux'),
    # " tab" → " languette"
    (re.compile(r'\btab\b', re.I), 'languette'),
    # " tabs" → " languettes"
    (re.compile(r'\btabs\b', re.I), 'languettes'),
    # "Dashes" → "Tirets"
    (re.compile(r'\bDashes\b'), 'Tirets'),
    # "dashes" → "tirets"
    (re.compile(r'\bdashes\b'), 'tirets'),
    # "format" → "format" (same)
    # "segments" → "segments" (same)
    # "style" → "style" (same)
    # cleanup double spaces
    (re.compile(r'  +'), ' '),
]

def apply_exact_and_regex(value):
    # 1. Exact match first
    if value in EXACT:
        return EXACT[value]
    # 2. Apply regex subs
    result = value
    for pat, repl in REGEX_SUBS:
        if callable(repl):
            result = pat.sub(repl, result)
        else:
            result = pat.sub(repl, result)
    return result

def process_file(path):
    try:
        content = open(path, encoding='utf-8', errors='replace').read()
    except Exception:
        return False

    original = content

    # Replace values in gui-text and gui-description attributes
    def replace_attr(m):
        attr = m.group(1)
        val = m.group(2)
        new_val = apply_exact_and_regex(val)
        if new_val != val:
            return f'{attr}="{new_val}"'
        return m.group(0)

    content = re.sub(r'(gui-text|gui-description)="([^"]+)"', replace_attr, content)

    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

modified = 0
total = 0
for root, dirs, files in os.walk(EXTENSIONS_DIR):
    for fname in files:
        if fname.endswith('.inx'):
            total += 1
            if process_file(os.path.join(root, fname)):
                modified += 1

print(f"Fichiers traités : {total} | Modifiés : {modified}")
