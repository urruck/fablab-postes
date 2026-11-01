# Extensions Inkscape « FabLab Boc@l »

La collection [MightyScape](https://github.com/eridur-de/mightyscape-1.2)
du FabLab Chemnitz, préparée pour les postes du Boc@l :

- **un seul dossier** : `extensions/fablab-bocal/` dans Inkscape ;
- **seulement les extensions qui fonctionnent** avec Inkscape 1.4 Flatpak
  (433 sur 480, toutes testées une par une), plus le **calepinage** maison ;
- **traduites en français phrase par phrase** (4 180 textes), et non plus mot à mot ;
- **rangées par usage** dans le menu *Extensions > FabLab Boc@l*.

## Installation

Le script de poste `fablab-poste.sh` l'appelle tout seul. Pour l'installer ou
le mettre à jour sur un compte, Inkscape fermé :

```bash
bash mightyscape/installer.sh
```

Sans accès à GitHub, avec un clone de `mightyscape-1.2` déjà présent :
`bash mightyscape/installer.sh --source /chemin/vers/mightyscape-1.2`

Le script :

1. récupère MightyScape à la version testée (`MIGHTYSCAPE_COMMIT` dans `installer.sh`) ;
2. construit `fablab-bocal/` avec `construire.py` ;
3. installe les bibliothèques Python (`dependances.txt`) **pour le Python
   d'Inkscape Flatpak**, dans `~/.var/app/org.inkscape.Inkscape/data/python` ;
4. met de côté l'ancien dossier `mightyscape-1.2` dans `~/.cache/fablab-bocal/`
   et retire le réglage « Python 3.10 » de l'ancien script, qui ne pouvait pas
   fonctionner avec Inkscape Flatpak.

## Menu Extensions > FabLab Boc@l

| Sous-menu | Contenu |
|---|---|
| Boîtes (Boxes.py) | 158 générateurs Boxes.py : boîtes, boîtes à flexion, plateaux et casiers, étagères, fixations murales, pièces et tests… Le nom d'origine est rappelé entre parenthèses pour retrouver la [documentation Boxes.py](https://florianfesti.github.io/boxes/html/index.html). |
| Boîtes (autres modèles) | boîtes à encoches, étuis et boîtes en carton |
| Découpe laser et traceur | **calepinage** (ranger les pièces sur la plaque), vérification avant découpe, attaches, ordre de découpe, imbrication, charnières souples, outils vpype |
| Chemins | modifier, couper et nettoyer, joindre et ordonner, opérations booléennes |
| Formes et motifs | générateurs, motifs à partir d'objets ou de chemins, textures |
| Mécanique et graduations | engrenages, crémaillères, échelles, frettes |
| Grilles, repères et mesures | grilles, repères d'étiquettes, cotes |
| Transformations | perspective, projections, mise à l'échelle |
| Texte, Tableaux, Couleurs, Calques et groupes | |
| Images et vectorisation | vectoriser une image matricielle |
| Papier et origami | origami, dépliage papercraft 3D |
| Jeux et puzzles | puzzles, labyrinthes |
| Import et export | export de la sélection, OpenSCAD, JPEG… |
| Divers | animation, optique, utilitaires |

Les formats d'import / export (G-code, GPX, WebP, DXF moderne…) apparaissent
dans *Fichier > Ouvrir* et *Fichier > Enregistrer sous*.

## Calepinage (extension maison)

*Extensions > FabLab Boc@l > Découpe laser et traceur > Calepinage* range les
objets sélectionnés sur une plaque (page actuelle, xTool P2 600 × 308 mm,
xTool F1 Ultra 220 × 220 mm ou taille libre) :

- écart entre les pièces et marge au bord réglables, nombre d'exemplaires ;
- rotation d'un quart de tour si elle fait gagner de la place ;
- s'il faut plusieurs plaques, elles sont posées à droite de la page, avec
  leurs contours dans un calque verrouillé « ne pas découper ».

Le rangement se fait par rectangles englobants : les formes ne s'emboîtent
pas les unes dans les autres. Pour emboîter des formes irrégulières, utiliser
**Deepnest**, installé sur les postes par `fablab-poste.sh` (menu des
applications) : enregistrer les pièces en SVG, les ouvrir dans Deepnest,
puis rouvrir le résultat dans Inkscape.

## Fichiers

| Fichier | Rôle |
|---|---|
| `installer.sh` | installation sur un compte |
| `construire.py` | construit `fablab-bocal/` à partir de MightyScape (Python standard, sans dépendance) |
| `classement.json` | rangement des menus (`categories`, `deplacer`) et extensions retirées (`retirer`) |
| `correctifs.py` | corrections de code pour Inkscape 1.4 Flatpak |
| `traductions/fr.json` | traductions françaises, phrase anglaise → phrase française |
| `traductions/boxes-mo.json` | traduction officielle de Boxes.py, reprise de son catalogue |
| `dependances.txt` | bibliothèques Python des extensions |
| `bocal/` | extensions maison (calepinage), copiées telles quelles |

## Corrections apportées

- **Boxes.py** : le lanceur demandait la commande `python`, absente du Flatpak.
  Il échouait aussi au moindre message (ex. PhotoFrame) et sur un champ vide (ex. TypeTray).
- **vpype** : l'aperçu demande Qt, absent du Flatpak ; il devient facultatif.
  Le module `occult` (lignes cachées) est installé.
- **SpiroGraph** : incompatibilité avec Inkscape 1.4.
- **Dépliage papercraft 3D** : chemin de bibliothèque codé en dur, visionneuse
  Qt facultative, incompatibilité avec Inkscape 1.4.

## Extensions retirées

| Extensions | Raison |
|---|---|
| inkcut_cut, inkcut_open | Inkcut non installé |
| open_in_visicut_add, open_in_visicut_replace | VisiCut lancé à part sur les postes |
| origami_patterns_old_bendy, origami_patterns_old_kresling | ancienne version |
| psd_export | demande GIMP en ligne de commande, incompatible avec Inkscape 1.4 |
| dxf2papercraft, sudoku, svg_embed_and_crop | demande Java |
| plycutter | demande Java et le module plycutter |
| paperfold | dépend d'openmesh (utiliser Dépliage papercraft 3D) |
| import_3d_mesh, slic3r_stl_input | dépend d'openmesh, indisponible pour le Python d'Inkscape |
| svg2fcsketch | dépend de FreeCAD |
| color_harmony | dépend de PyQt4, obsolète |
| output_pro | dépend de PyQt5 |
| ocr | dépend de Tesseract |
| nextgenerator | fichier .inx invalide |
| inventory_sticker | imprimante d'étiquettes réseau du FabLab Chemnitz |
| edit_stroke_font, gen_stroke_font_data, render_stroke_font_text, stroke_font_templ, sync_stroke_font | incompatible avec Inkscape 1.4 |
| shape_recognition | instable |
| open_in_roland_cutstudio | lance Roland CutStudio (Windows) |
| about_upgrade_mightyscape | mise à jour automatique : écraserait la version Boc@l |
| vpypetools_deduplicate | module vpype-dedupe introuvable |
| origami_patterns_cylindrical_template, origami_patterns_template | modèle pour développeurs |
| open_extensions_dir | outil de développeur |
| animate_order | ouvre un navigateur web depuis le bac à sable Flatpak |
| plotty | pilote de traceur série, non utilisé au Boc@l |
| fillet_and_chamfer, round_corners | remplacé par l'effet de chemin Inkscape « Congé et chanfrein » |
| dimensioning | remplacé par l'effet de chemin Inkscape « Cotation » |
| ellipse_by_five_points | remplacé par l'effet de chemin Inkscape « Ellipse par 5 points » |
| circle_tangents | remplacé par le magnétisme d'Inkscape |
| cutting_optimizer | le programme CutOptim sature la mémoire (30 Go) et bloque le poste ; remplacé par le Calepinage maison |
| les 7 générateurs Boxes.py « Unstable » | instables selon Boxes.py lui-même |

## Mettre à jour MightyScape

1. Changer `MIGHTYSCAPE_COMMIT` dans `installer.sh`.
2. `python3 construire.py --manquantes CLONE/extensions/fablabchemnitz` liste
   les nouveaux textes à traduire : les ajouter à `traductions/fr.json`.
3. Si `construire.py` s'arrête sur « Correctif à revoir » ou « Catégorie
   inconnue », adapter `correctifs.py` ou `classement.json`.
4. Tester dans Inkscape, puis pousser.
