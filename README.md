# fablab-postes

Script d'installation des postes Linux du FabLab **Le Boc@l**
(Centre Social et Socioculturel du Chemillois, Chemillé-en-Anjou).

Il transforme une installation neuve en poste prêt pour le fablab :
logiciels de création, de fabrication numérique et d'électronique,
droits d'accès aux cartes Arduino, et Firefox avec les favoris du lab.

## Systèmes pris en charge

- Zorin OS 18
- Ubuntu 24.04 LTS
- Linux Mint 22.x

Le script détecte le système et s'adapte tout seul. Sur une autre base
qu'Ubuntu 24.04, il prévient et demande confirmation.

## Utilisation

```bash
git clone https://github.com/urruck/fablab-postes.git
cd fablab-postes
sudo bash fablab-poste.sh
```

xTool Studio est téléchargé automatiquement depuis le cloud du CSC
(version la plus récente du partage). Pour une installation sans
internet ou avec une version précise, déposez le .deb dans `paquets/` :
il sera utilisé en priorité.

Redémarrez ensuite le poste. Le script ne s'arrête pas sur une erreur :
il affiche à la fin ce qui reste à reprendre à la main.
Journal complet : `/var/log/fablab-install.log`

## Ce qui est installé

| Domaine | Logiciels |
|---|---|
| Vectoriel | Inkscape, Ink/Stitch (broderie), MightyScape (extensions du FabLab Chemnitz) |
| Découpe laser | xTool Studio (téléchargé depuis le cloud du CSC), VisiCut |
| 3D et CAO | FreeCAD, Blender, OpenSCAD, MeshLab, LibreCAD, Sweet Home 3D |
| Impression 3D | PrusaSlicer, Ultimaker Cura, OrcaSlicer |
| Électronique | Arduino IDE 2, KiCad, Fritzing, Thonny, esptool |
| Création | GIMP, Krita, Scribus, Audacity, Kdenlive, OBS Studio |
| Langue | Interface, correcteurs et LibreOffice en français |

## Droits Arduino et ports série

- le compte principal rejoint les groupes `dialout` et `plugdev` ;
- les comptes créés plus tard reçoivent ces droits automatiquement ;
- une règle udev ouvre les ports USB série à tout le monde (postes partagés) ;
- `brltty` est retiré, car il bloque les puces CH340 des clones Arduino.

## Firefox

Page d'accueil : [bocal.csc49.fr](https://bocal.csc49.fr).
Barre personnelle : Le Boc@l, Fab-Manager, puis des dossiers
**Fraisage CNC**, **Découpe laser**, **Impression 3D**, **FreeCAD**,
**Textile**, **Électronique**, **Réparation** et **Réseaux**.
Les favoris se modifient dans la section 8 du script.

## Licence

GPL v3, voir [LICENSE](LICENSE).
