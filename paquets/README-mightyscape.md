# MightyScape — Extensions FabLab Chemnitz pour Inkscape

**MightyScape** est une collection de ~240 extensions pour Inkscape, maintenue par le
[FabLab Chemnitz](https://fablabchemnitz.de) (Allemagne). Elle ajoute dans Inkscape le
sous-menu **Extensions → FabLab Chemnitz** et couvre : découpe laser, boîtes, maillages
3D, tracés géométriques, export multi-format, etc.

- Dépôt officiel : <https://github.com/eridur-de/mightyscape-1.2>
- Version Inkscape requise : 1.2 ou supérieure
- Version testée ici : Inkscape **1.4.4 Flatpak** sur Ubuntu

---

## Installation rapide

```bash
bash install-mightyscape.sh
```

Le script détecte automatiquement Inkscape Flatpak, clone MightyScape, crée un
environnement Python isolé et installe toutes les dépendances.

---

## Dépendances système expliquées

| Paquet apt | Pourquoi |
|---|---|
| `git` | Cloner le dépôt MightyScape et permettre la mise à jour depuis Inkscape via l'extension *Upgrade MightyScape* |
| `cmake` + `ninja-build` | Compiler **openmesh** (bibliothèque C++ de maillages 3D) — aucun wheel pré-compilé disponible pour Linux x86_64, la compilation depuis les sources est obligatoire |
| `python3.10` + `python3.10-dev` + `python3.10-venv` | MightyScape crée un environnement virtuel Python 3.10 isolé dans son propre dossier. Les headers `-dev` sont indispensables pour compiler openmesh |
| `curl` | Télécharger l'installeur de **uv** (gestionnaire de paquets Python) |
| `libgirepository-2.0-dev` | Bindings GObject/GLib pour Python — requis par certaines extensions qui interagissent avec l'interface GTK d'Inkscape |
| `xmlstarlet` | Édition XML en ligne de commande pour modifier `preferences.xml` (optionnel, le script utilise `sed` en fallback) |

---

## Paquets Python expliqués

### Traitement d'image — `Pillow`

**Extensions concernées :**
`export_selection_as`, `image_triangulation`, `imagetracerjs`, `kvec`, `laser_check`,
`low_poly_2`, `ocr`, `pixel2svg`, `pixels2objects`, `primitive`, `raster_perspective`,
`webp_import`

Pillow (PIL) est la bibliothèque de référence pour lire, modifier et sauvegarder des
images raster en Python. Ces extensions l'utilisent pour importer des bitmaps (PNG, JPG,
WebP…), appliquer des effets ou convertir des images en SVG.

---

### Calcul scientifique — `numpy`

**Extensions concernées :** la majorité des extensions de génération géométrique
(`hatch_fill`, `netting`, `spirograph`, `guilloche_creations`, `maze`, `delaunay_triangulation`…)

numpy est la base de tout calcul numérique Python. Utilisé pour les matrices de
transformation, le tracé de courbes paramétriques et les opérations vectorielles sur
les chemins SVG.

---

### Analyse de couleurs — `scikit-learn`

**Extension concernée :** `color_harmony`

scikit-learn fournit les algorithmes de clustering (k-means) utilisés par color_harmony
pour analyser la palette d'un document et suggérer des harmonies colorées cohérentes.

---

### Traitement de graphes — `networkx`

**Extension concernée :** `paperfold`

networkx représente le maillage 3D comme un graphe de faces adjacentes. L'algorithme de
dépliage (spanning tree) parcourt ce graphe pour "aplatir" le modèle 3D en patron 2D
imprimable sans chevauchements.

---

### Maillages 3D — `openmesh` (+ `pybind11`)

**Extensions concernées :** `import_3d_mesh`, `paperfold`, `slic3r_stl_input`

OpenMesh est une bibliothèque C++ de référence pour la manipulation de maillages
polygonaux (half-edge data structure). Elle permet de lire/écrire des fichiers OBJ, STL,
OFF et d'effectuer des opérations topologiques sur les maillages.

- `import_3d_mesh` : importe un fichier OBJ/STL/OFF dans Inkscape en SVG
- `paperfold` : déplie un maillage 3D en patron papercraft 2D (requiert aussi networkx)
- `slic3r_stl_input` : importe la vue en tranches d'un STL depuis Slic3r

`pybind11` est le bridge C++/Python utilisé par openmesh pour exposer son API C++ à Python.

> **Note :** openmesh n'a pas de wheel pré-compilé sur PyPI pour Linux — il se compile
> depuis les sources (~90 secondes). C'est pourquoi `python3.10-dev` et `cmake` sont
> indispensables.

---

### Rendu 3D / Papercraft — `pygame` + `PyOpenGL`

**Extension concernée :** `papercraft_unfold`

`papercraft_unfold` affiche une prévisualisation 3D interactive du modèle avant de
générer le patron SVG. Elle s'appuie sur :
- **pygame** : gestion de la fenêtre et des événements clavier/souris
- **PyOpenGL** : rendu OpenGL 3D du maillage dans cette fenêtre

---

### Simulation optique — `raytracing`

**Extension concernée :** `raytracing`

Le paquet `raytracing` (de Doric Lenses) implémente un lancer de rayons paraxial pour
simuler des systèmes optiques (lentilles, miroirs, fibres). L'extension Inkscape permet
de dessiner directement le schéma optique d'un système et de visualiser les trajectoires
des rayons lumineux.

---

### Mise à jour depuis Inkscape — `GitPython`

**Extension concernée :** `about_upgrade_mightyscape`

GitPython permet d'exécuter des commandes git depuis Python. L'extension *Upgrade
MightyScape* (Extensions → FabLab Chemnitz → About/Upgrade MightyScape) l'utilise pour
faire un `git pull` et mettre à jour les extensions sans quitter Inkscape.

---

### Interface graphique Qt — `PyQt5`

**Extension concernée :** `output_pro`

`output_pro` est un exportateur multi-format avancé avec une interface graphique
indépendante (fenêtre Qt). Il permet d'exporter en masse des éléments SVG vers PNG,
PDF, DXF, etc. avec des options de rendu fin. PyQt5 fournit cette interface.

---

### Optimisation de tracés laser — `vpype`

**Extension concernée :** `vpypetools`

vpype est un préprocesseur de fichiers vectoriels spécialisé pour les traceurs et
découpeuses laser. L'extension vpypetools permet d'appliquer directement depuis Inkscape
les optimisations vpype : réordonnancement des chemins, fusion de segments, filtrage
par longueur, etc. — ce qui réduit le temps de découpe sur la laser.

---

### Maillages légers — `trimesh`

**Extension concernée :** diverses extensions d'import 3D

trimesh est une bibliothèque Python pour la lecture et la manipulation de maillages 3D
(STL, OBJ, PLY…). Plus légère qu'openmesh, elle est utilisée dans les extensions qui
n'ont pas besoin de la topologie complète half-edge.

---

### Analyse XML — `lxml`

**Extensions concernées :** `paperfold`, `slic3r_stl_input`, `papercraft_unfold`,
`dxf2papercraft` et une dizaine d'autres

lxml est le parser XML/SVG haute performance utilisé par la plupart des extensions qui
manipulent directement le document SVG (lecture de balises, modification d'attributs,
injection de nouveaux éléments).

---

## Architecture de l'installation

```
~/.var/app/org.inkscape.Inkscape/config/inkscape/
├── preferences.xml          ← python-interpreter modifié pour pointer vers le venv
└── extensions/
    └── mightyscape-1.2/     ← dépôt git cloné ici
        ├── bin/
        │   └── python3      ← Python 3.10 du venv isolé
        ├── lib/             ← tous les paquets Python installés ici
        └── extensions/
            └── fablabchemnitz/
                ├── about_upgrade_mightyscape/
                ├── boxes.py/
                ├── hatch_fill/
                └── ...      ← ~240 extensions
```

Le venv est **isolé dans le dossier MightyScape** : aucune dépendance n'est installée
dans le Python système. Cela évite les conflits avec d'autres logiciels.

---

## Extensions non fonctionnelles (limites connues)

| Extension | Raison |
|---|---|
| `color_harmony` (fonctions de palette/stockage) | Dépend de `PyQt4` (obsolète, non disponible pour Python 3) — le cœur de l'extension fonctionne, seules les fonctions d'import/export de palettes tierces sont inactives |

---

## Mise à jour de MightyScape

Depuis Inkscape : **Extensions → FabLab Chemnitz → About/Upgrade MightyScape**

Ou en ligne de commande :
```bash
git -C ~/.var/app/org.inkscape.Inkscape/config/inkscape/extensions/mightyscape-1.2 pull
```

---

*Document rédigé pour le Boc@l FabLab — Centre Social Chemillé Melay*
