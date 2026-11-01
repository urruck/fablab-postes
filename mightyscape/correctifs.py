"""Correctifs de code appliqués aux extensions MightyScape pour Inkscape 1.4 (Flatpak).

Chaque correctif : (fichier relatif au dossier des extensions, texte original, remplacement).
Le texte original doit être présent exactement une fois, sinon la construction s'arrête :
c'est le signe que MightyScape a changé et que le correctif est à revoir.
"""

CORRECTIFS = [
    # --- Boxes.py : le lanceur ---
    # Inkscape Flatpak ne définit pas toujours INKSCAPE_PROFILE_DIR
    ("boxes.py/boxes_proxy.py",
     '        preferencesPath = os.environ["INKSCAPE_PROFILE_DIR"]',
     '        preferencesPath = os.environ.get("INKSCAPE_PROFILE_DIR", "")'),
    ("boxes.py/boxes_proxy.py",
     '        tree = ET.parse(preferencesXml)\n        root = tree.getroot()',
     '        root = ET.parse(preferencesXml).getroot() if os.path.isfile(preferencesXml) else ET.Element("x")'),
    # Le Flatpak n'a pas de commande "python" : on reprend le Python qui exécute l'extension
    ("boxes.py/boxes_proxy.py",
     '            PYTHONBIN = "python"',
     '            PYTHONBIN = sys.executable  # Boc@l : Flatpak sans commande "python"'),
    # Un champ vide (ex. fichier d'étiquettes de TypeTray) était transmis comme "None"
    ("boxes.py/boxes_proxy.py",
     '                if arg in ("input_file", "tab"):\n                    continue',
     '                if arg in ("input_file", "tab"):\n                    continue\n'
     '                if str(getattr(self.options, arg)) in ("", "None"):  # Boc@l : champ vide = valeur par défaut\n'
     '                    continue'),
    # Un simple message de boxes.py (ex. PhotoFrame) faisait échouer la génération
    ("boxes.py/boxes_proxy.py",
     '        if stderr.decode(\'utf-8\') != "":',
     '        if proc.returncode != 0:  # Boc@l : un message sur stderr n\'est pas une erreur'),

    # --- vpype : l'aperçu demande Qt (PySide6), absent du Flatpak ---
    ("vpypetools/vpypetools.py",
     "import vpype_viewer\nfrom vpype_viewer import ViewMode\n",
     ""),
    ("vpypetools/vpypetools.py",
     "            vpype_viewer.show(doc,",
     "            try:  # Boc@l : aperçu facultatif (PySide6 absent du Flatpak)\n"
     "                import vpype_viewer\n"
     "                from vpype_viewer import ViewMode\n"
     "            except ImportError:\n"
     "                inkex.utils.debug(\"Aperçu vpype indisponible (PySide6 non installé).\")\n"
     "                vpype_viewer = None\n"
     "            if vpype_viewer: vpype_viewer.show(doc,"),

    # --- SpiroGraph : get_ids() ne renvoie plus un ensemble modifiable (inkex 1.4) ---
    ("spirograph/inkscapeMadeEasy/inkscapeMadeEasy_Base.py",
     "        self.svg.get_ids().add(new_id)",
     '        getattr(self.svg.get_ids(), "add", lambda _i: None)(new_id)  # Boc@l : inkex 1.4'),
    ("spirograph/inkscapeMadeEasy/inkscapeMadeEasy_Draw.py",
     "            ExtensionBaseObj.svg.get_ids().add(nameID)",
     '            getattr(ExtensionBaseObj.svg.get_ids(), "add", lambda _i: None)(nameID)  # Boc@l : inkex 1.4'),
    ("spirograph/inkscapeMadeEasy/inkscapeMadeEasy_Draw.py",
     "marker_lineline_attribs)\n\n        ExtensionBaseObj.svg.get_ids().add(nameID)",
     'marker_lineline_attribs)\n\n        getattr(ExtensionBaseObj.svg.get_ids(), "add", lambda _i: None)(nameID)  # Boc@l : inkex 1.4'),

    # --- Dépliage papercraft 3D ---
    # Chemin de bibliothèque codé en dur sur la machine du développeur
    ("papercraft_unfold/admesh/linux/admesh",
     'LD_LIBRARY_PATH="/home/tomate/mightyscape/papercraft_unfold/admesh/linux/.libs:',
     'LD_LIBRARY_PATH="$progdir:'),
    # Visionneuse fstl (Qt5) facultative
    ("papercraft_unfold/papercraft_unfold.py",
     "            p = Popen(fstl_cmd, shell=True)\n            p.wait()",
     "            try:  # Boc@l : visionneuse fstl facultative (Qt5 absent du Flatpak)\n"
     "                p = Popen(fstl_cmd, shell=True, stderr=subprocess.DEVNULL)\n"
     "                p.wait()\n"
     "            except Exception:\n"
     "                pass"),
    # inkex 1.4 : bounding_box n'accepte plus un élément lxml brut
    ("papercraft_unfold/papercraft_unfold.py",
     "            bbox = inkex.elements._selected.ElementList.bounding_box(doc)",
     "            try:  # Boc@l : API inkex 1.4\n"
     "                bbox = inkex.elements._selected.ElementList.bounding_box(doc)\n"
     "            except (ValueError, AttributeError, TypeError):\n"
     "                bbox = None"),
]
