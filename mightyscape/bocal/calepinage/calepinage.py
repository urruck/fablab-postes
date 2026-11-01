#!/usr/bin/env python3
"""Calepinage FabLab Boc@l : range les objets sélectionnés sur des plaques.

Algorithme MaxRects (meilleur ajustement du petit côté) sur les rectangles
englobants, avec rotation d'un quart de tour facultative et autant de
plaques que nécessaire. Licence GPL-3.0-ou-ultérieure.
"""

import inkex
from inkex import Transform

PLAQUES = {"p2": (600.0, 308.0), "f1ultra": (220.0, 220.0)}
CALQUE_PLAQUES = "Calepinage – plaques (ne pas découper)"
ESPACE_PLAQUES = 20.0  # mm entre deux plaques posées côte à côte
MAX_PLAQUES = 100


class Plaque:
    """Une plaque vide de largeur l et hauteur h (MaxRects)."""

    def __init__(self, l, h):
        self.libres = [(0.0, 0.0, l, h)]

    def meilleure_place(self, w, h, rotation):
        meilleur = None
        for (x, y, fw, fh) in self.libres:
            for (pw, ph, tourne) in ((w, h, False), (h, w, True)) if rotation else ((w, h, False),):
                if pw <= fw + 1e-9 and ph <= fh + 1e-9:
                    score = (min(fw - pw, fh - ph), max(fw - pw, fh - ph))
                    if meilleur is None or score < meilleur[0]:
                        meilleur = (score, x, y, pw, ph, tourne)
        return meilleur

    def occuper(self, x, y, w, h):
        nouveaux = []
        for (fx, fy, fw, fh) in self.libres:
            if x >= fx + fw or x + w <= fx or y >= fy + fh or y + h <= fy:
                nouveaux.append((fx, fy, fw, fh))
                continue
            if x > fx:
                nouveaux.append((fx, fy, x - fx, fh))
            if x + w < fx + fw:
                nouveaux.append((x + w, fy, fx + fw - x - w, fh))
            if y > fy:
                nouveaux.append((fx, fy, fw, y - fy))
            if y + h < fy + fh:
                nouveaux.append((fx, y + h, fw, fy + fh - y - h))
        nouveaux = [r for r in nouveaux if r[2] > 1e-9 and r[3] > 1e-9]
        self.libres = [r for i, r in enumerate(nouveaux)
                       if not any(j != i and contient(s, r) and (s != r or j < i)
                                  for j, s in enumerate(nouveaux))]


def contient(a, b):
    return (a[0] <= b[0] + 1e-9 and a[1] <= b[1] + 1e-9
            and a[0] + a[2] >= b[0] + b[2] - 1e-9 and a[1] + a[3] >= b[1] + b[3] - 1e-9)


class Calepinage(inkex.EffectExtension):
    def add_arguments(self, pars):
        pars.add_argument("--onglets")
        pars.add_argument("--plaque", default="page")
        pars.add_argument("--largeur", type=float, default=300.0)
        pars.add_argument("--hauteur", type=float, default=200.0)
        pars.add_argument("--ecart", type=float, default=2.0)
        pars.add_argument("--marge", type=float, default=3.0)
        pars.add_argument("--copies", type=int, default=1)
        pars.add_argument("--rotation", type=inkex.Boolean, default=True)
        pars.add_argument("--page", type=inkex.Boolean, default=True)

    def effect(self):
        o = self.options
        svg = self.svg
        mm = svg.unittouu("1mm")  # unités du document pour 1 mm

        objets = [e for e in svg.selection.values() if isinstance(e, inkex.ShapeElement)
                  and not isinstance(e, inkex.Layer)]
        if not objets:
            raise inkex.AbortExtension("Sélectionnez d'abord les pièces à ranger.")

        if o.plaque == "page":
            L, H = svg.viewbox_width, svg.viewbox_height
        else:
            lm, hm = PLAQUES.get(o.plaque, (o.largeur, o.hauteur))
            L, H = lm * mm, hm * mm
        ecart, marge = o.ecart * mm, o.marge * mm
        utile_l, utile_h = L - 2 * marge + ecart, H - 2 * marge + ecart
        if utile_l <= 0 or utile_h <= 0:
            raise inkex.AbortExtension("La marge est plus grande que la plaque.")

        # Pièces (avec les exemplaires demandés), rectangle englobant dans le repère du document
        pieces = []
        for e in objets:
            for n in range(o.copies):
                piece = e if n == 0 else e.duplicate()
                bb = piece.bounding_box(piece.getparent().composed_transform())
                if bb is None or bb.width <= 0 or bb.height <= 0:
                    continue
                pieces.append((piece, bb))
        pieces.sort(key=lambda p: (max(p[1].width, p[1].height), p[1].width * p[1].height), reverse=True)

        plaques, places, trop_grandes = [], [], []
        for piece, bb in pieces:
            w, h = bb.width + ecart, bb.height + ecart
            choix = None
            for i, pl in enumerate(plaques):
                m = pl.meilleure_place(w, h, o.rotation)
                if m:
                    choix = (i, m)
                    break
            if choix is None:
                neuve = Plaque(utile_l, utile_h)
                m = neuve.meilleure_place(w, h, o.rotation)
                if m is None or len(plaques) >= MAX_PLAQUES:
                    trop_grandes.append(piece)
                    continue
                plaques.append(neuve)
                choix = (len(plaques) - 1, m)
            i, (_, x, y, pw, ph, tourne) = choix
            plaques[i].occuper(x, y, pw, ph)
            places.append((piece, bb, i, x, y, tourne))

        if o.page and o.plaque != "page":
            self.page_a_la_taille(L, H)
        origine_x, origine_y = self.origine_page()

        for piece, bb, i, x, y, tourne in places:
            ox = origine_x + i * (L + ESPACE_PLAQUES * mm) + marge + x
            oy = origine_y + marge + y
            cx, cy = bb.center.x, bb.center.y
            if tourne:
                # quart de tour autour du centre, puis coin haut-gauche en (ox, oy)
                doc = (Transform(translate=(ox + bb.height / 2, oy + bb.width / 2))
                       @ Transform(rotate=90) @ Transform(translate=(-cx, -cy)))
            else:
                doc = Transform(translate=(ox - bb.left, oy - bb.top))
            parent = piece.getparent().composed_transform()
            piece.transform = (-parent) @ doc @ parent @ piece.transform

        if len(plaques) > 1:
            self.dessiner_plaques(len(plaques), L, H, origine_x, origine_y, mm)

        bilan = f"{len(places)} pièce(s) rangée(s) sur {len(plaques)} plaque(s)."
        if trop_grandes:
            for p in trop_grandes:
                if p not in objets:
                    p.delete()
            bilan += (f"\n{sum(1 for p in trop_grandes if p in objets)} pièce(s) trop grande(s) "
                      "pour la plaque : laissée(s) à sa place.")
        if len(plaques) > 1:
            bilan += f"\nPlaques 2 à {len(plaques)} : à droite de la page."
        self.msg(bilan)

    def origine_page(self):
        vb = self.svg.get_viewbox()
        return (vb[0], vb[1]) if vb and any(vb) else (0.0, 0.0)

    def page_a_la_taille(self, L, H):
        svg = self.svg
        unite = svg.document_unit or "mm"
        x0, y0 = self.origine_page()
        echelle = svg.unittouu(f"1{unite}")
        svg.set("width", f"{L / echelle:g}{unite}")
        svg.set("height", f"{H / echelle:g}{unite}")
        svg.set("viewBox", f"{x0:g} {y0:g} {L:g} {H:g}")
        pages = svg.namedview.get_pages() if hasattr(svg.namedview, "get_pages") else []
        if len(pages) == 1:
            pages[0].set("width", f"{L:g}")
            pages[0].set("height", f"{H:g}")

    def dessiner_plaques(self, n, L, H, x0, y0, mm):
        svg = self.svg
        calque = None
        for c in svg.findall("svg:g[@inkscape:groupmode='layer']"):
            if c.label == CALQUE_PLAQUES:
                calque = c
                for enfant in list(c):
                    enfant.delete()
        if calque is None:
            calque = svg.add(inkex.Layer.new(CALQUE_PLAQUES))
        calque.set("sodipodi:insensitive", "true")
        for i in range(n):
            r = calque.add(inkex.Rectangle.new(x0 + i * (L + ESPACE_PLAQUES * mm), y0, L, H))
            r.style = {"fill": "none", "stroke": "#9e9e9e", "stroke-width": f"{0.3 * mm:g}",
                       "stroke-dasharray": f"{3 * mm:g},{2 * mm:g}"}
            t = calque.add(inkex.TextElement(x=f"{x0 + i * (L + ESPACE_PLAQUES * mm):g}",
                                             y=f"{y0 - 2 * mm:g}"))
            t.text = f"Plaque {i + 1}"
            t.style = {"font-size": f"{5 * mm:g}", "fill": "#9e9e9e"}


if __name__ == "__main__":
    Calepinage().run()
