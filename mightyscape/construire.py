#!/usr/bin/env python3
"""Construit le dossier d'extensions « FabLab Boc@l » à partir de MightyScape.

    python3 construire.py SOURCE DESTINATION
        SOURCE      : dossier extensions/fablabchemnitz d'un clone de mightyscape-1.2
        DESTINATION : dossier à créer (ex. ~/.var/app/org.inkscape.Inkscape/config/inkscape/extensions/fablab-bocal)

    python3 construire.py --manquantes SOURCE
        liste les textes encore sans traduction (pour compléter traductions/fr.json)

Étapes : ne garder que les extensions retenues (classement.json), appliquer les
correctifs de code (correctifs.py), traduire les textes phrase par phrase
(traductions/fr.json) et ranger les menus (classement.json).
Aucune dépendance : Python 3 standard.
"""
import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from correctifs import CORRECTIFS  # noqa: E402

NS = "http://www.inkscape.org/namespace/inkscape/extension"
Q = "{%s}" % NS
ET.register_namespace("", NS)

CLASSEMENT = json.load(open(os.path.join(ICI, "classement.json"), encoding="utf-8"))
# Traductions : celles de Boxes.py (boxes-mo.json, tirées de sa traduction officielle),
# puis les nôtres (fr.json), prioritaires.
FR = {}
for _f in ("boxes-mo.json", "fr.json"):
    _p = os.path.join(ICI, "traductions", _f)
    if os.path.exists(_p):
        _t = json.load(open(_p, encoding="utf-8"))
        # le catalogue Boxes.py traduit aussi des lettres isolées hors contexte (« b » -> « si ») : on les ignore
        FR.update({k: v for k, v in _t.items() if _f == "fr.json" or len(k) > 2})

ATTRS = ("gui-text", "_gui-text", "gui-description", "_gui-description")
TEXTES = ("name", "_name", "label", "_label", "option", "_option", "item", "_item")


def tag(e):
    return e.tag.replace(Q, "") if isinstance(e.tag, str) else ""


def inx_de(source):
    for d, _, fs in os.walk(source):
        for f in fs:
            if f.endswith(".inx"):
                yield os.path.join(d, f)


def ancienne_categorie(racine):
    menus = [s.get("name") or s.get("_name") or "" for s in racine.iter(Q + "submenu")]
    return "/".join(menus[1:])


def destination_menu(nom_inx, racine):
    """Nouveau sous-menu (chemin « A/B »), ou None si l'extension est retirée."""
    if nom_inx in CLASSEMENT["retirer"]:
        return None
    if nom_inx in CLASSEMENT["deplacer"]:
        return CLASSEMENT["deplacer"][nom_inx]
    ancien = ancienne_categorie(racine)
    if ancien not in CLASSEMENT["categories"]:
        raise SystemExit(f"Catégorie inconnue « {ancien} » ({nom_inx}) : à ajouter dans classement.json")
    return CLASSEMENT["categories"][ancien]


def textes(racine):
    """(élément, attribut ou None) de chaque texte affiché à traduire."""
    nom = racine.find(Q + "name")
    if nom is None:
        nom = racine.find(Q + "_name")
    for e in racine.iter():
        t = tag(e)
        for a in ATTRS:
            if e.get(a) and e.get(a).strip():
                yield e, a
        if t in TEXTES and e.text and e.text.strip():
            if t in ("name", "_name") and e is not nom:
                continue
            if t in ("label", "_label") and e.get("appearance") == "url":
                continue
            yield e, None
        elif t == "param" and e.get("type") == "description" and e.text and e.text.strip():
            yield e, None


def lire(e, a):
    return (e.get(a) if a else e.text).strip()


def traduisible(s):
    return bool(re.search(r"[A-Za-z]{2}", s)) and not re.fullmatch(r"[\w.\-]+_[\w.\-]*|[A-Za-z]\w*\d\w*", s)


def traduire(racine, manquantes=None, garder_nom=False):
    """garder_nom : ajoute le nom d'origine entre parenthèses (générateurs Boxes.py,
    pour retrouver leur documentation et leurs exemples en ligne)."""
    nom = racine.find(Q + "name")
    for e, a in textes(racine):
        s = lire(e, a)
        fr = FR.get(s)
        if fr is None:
            if manquantes is not None and traduisible(s):
                manquantes.add(s)
            continue
        if garder_nom and e is nom:
            fr = f"{fr} ({s})"
        if a:
            e.set(a, fr)
        else:
            # option sans valeur : Inkscape transmettrait le texte affiché, on garde l'original
            if tag(e) in ("option", "_option", "item", "_item") and e.get("value") is None:
                e.set("value", s)
            e.text = fr


def ranger_menu(racine, chemin):
    """Remplace la chaîne de sous-menus par « FabLab Boc@l / chemin »."""
    for parent in racine.iter():
        if tag(parent) == "effects-menu":
            for s in list(parent):
                if tag(s) == "submenu":
                    parent.remove(s)
            noeud = parent
            for nom in [CLASSEMENT["menu_racine"]] + [p for p in chemin.split("/") if p]:
                noeud = ET.SubElement(noeud, Q + "submenu", {"name": nom})
            return


def construire(source, destination):
    source = os.path.abspath(source)
    gardes, retires = {}, []
    for inx in inx_de(source):
        nom = os.path.basename(inx)[:-4]
        try:
            racine = ET.parse(inx).getroot()
        except ET.ParseError:
            retires.append(nom)
            continue
        chemin = destination_menu(nom, racine)
        if chemin is None:
            retires.append(nom)
        else:
            gardes[inx] = chemin
    dossiers = {os.path.relpath(os.path.dirname(i), source).split(os.sep)[0] for i in gardes}

    if os.path.exists(destination):
        shutil.rmtree(destination)
    os.makedirs(destination)
    for d in sorted(dossiers):
        shutil.copytree(os.path.join(source, d), os.path.join(destination, d), symlinks=True,
                        ignore=shutil.ignore_patterns("__pycache__", ".git*"))
    # .inx retirés à l'intérieur d'un dossier gardé
    for inx in inx_de(destination):
        if os.path.join(source, os.path.relpath(inx, destination)) not in gardes:
            os.remove(inx)

    for fichier, avant, apres in CORRECTIFS:
        p = os.path.join(destination, fichier)
        if not os.path.exists(p):
            continue
        s = open(p, encoding="utf-8").read()
        if s.count(avant) != 1:
            raise SystemExit(f"Correctif à revoir : {fichier} ({s.count(avant)} occurrences de {avant[:60]!r})")
        open(p, "w", encoding="utf-8").write(s.replace(avant, apres))

    for inx, chemin in gardes.items():
        cible = os.path.join(destination, os.path.relpath(inx, source))
        arbre = ET.parse(cible)
        racine = arbre.getroot()
        traduire(racine, garder_nom=os.path.basename(os.path.dirname(inx)) == "boxes.py")
        ranger_menu(racine, chemin)
        arbre.write(cible, encoding="UTF-8", xml_declaration=True)

    # Extensions maison du Boc@l (déjà en français, menus déjà rangés)
    maison = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bocal")
    for d in sorted(os.listdir(maison)) if os.path.isdir(maison) else []:
        if os.path.exists(os.path.join(destination, d)):
            raise SystemExit(f"Extension maison {d} : nom déjà pris par MightyScape")
        shutil.copytree(os.path.join(maison, d), os.path.join(destination, d),
                        ignore=shutil.ignore_patterns("__pycache__"))
        gardes[os.path.join(maison, d)] = d

    with open(os.path.join(destination, "LISEZMOI-BOCAL.txt"), "w", encoding="utf-8") as f:
        f.write("Extensions FabLab Boc@l : MightyScape (https://github.com/eridur-de/mightyscape-1.2)\n"
                "trié, corrigé pour Inkscape 1.4 Flatpak et traduit en français.\n"
                "Ne pas modifier ici : ce dossier est reconstruit par mightyscape/installer.sh\n"
                "(dépôt https://github.com/urruck/fablab-postes).\n\n"
                f"{len(gardes)} extensions. Retirées : {', '.join(sorted(retires))}\n")
    print(f"{len(gardes)} extensions construites dans {destination} ({len(retires)} retirées)")


def manquantes(source):
    m = set()
    for inx in inx_de(source):
        try:
            racine = ET.parse(inx).getroot()
        except ET.ParseError:
            continue
        if destination_menu(os.path.basename(inx)[:-4], racine) is not None:
            traduire(racine, m)
    return sorted(m)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--manquantes":
        json.dump(manquantes(sys.argv[2]), sys.stdout, ensure_ascii=False, indent=0)
    elif len(sys.argv) == 3:
        construire(sys.argv[1], sys.argv[2])
    else:
        sys.exit(__doc__)
