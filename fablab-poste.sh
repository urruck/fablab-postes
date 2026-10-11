#!/usr/bin/env bash
# =====================================================================
#  Installation d'un poste FabLab Le Boc@l (CSC du Chemillois)
#  Cibles : Zorin OS 18, Ubuntu 24.04 LTS, Linux Mint 22.x
#  (toutes basées sur Ubuntu 24.04 "noble"), installation neuve
#  Le script détecte le système et s'adapte tout seul.
#
#  Usage :
#    1. Mettre ce script dans un dossier, avec un sous-dossier "paquets/"
#       contenant le .deb de xTool Studio (ex. paquets/xTool-Studio_x.y.z.deb)
#    2. Ouvrir un terminal dans ce dossier puis lancer :
#         sudo bash fablab-poste.sh
#    3. Redémarrer à la fin (pour les droits Arduino notamment)
#
#  Le script ne s'arrête pas sur une erreur : il continue et affiche
#  à la fin la liste de ce qui n'a pas pu s'installer.
#  Journal complet : /var/log/fablab-install.log
# =====================================================================

set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------
#  Réglages (à adapter si besoin)
# ---------------------------------------------------------------------
PAGE_ACCUEIL="https://bocal.csc49.fr"
DOSSIER_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOSSIER_PAQUETS="${DOSSIER_SCRIPT}/paquets"
JOURNAL="/var/log/fablab-install.log"

# Guide FreeCAD de Lachiver (parcours web)
LIEN_TUTOS_LACHIVER="https://freecad.lachiver.fr/v26.3/guideW/co/ParcoursWeb.html"

# ---------------------------------------------------------------------
#  Outils internes
# ---------------------------------------------------------------------
ECHECS=()
VERT="\e[32m"; ROUGE="\e[31m"; JAUNE="\e[33m"; RAZ="\e[0m"

titre() { echo -e "\n${JAUNE}==== $* ====${RAZ}" | tee -a "$JOURNAL"; }
ok()    { echo -e "${VERT}  ✓ $*${RAZ}" | tee -a "$JOURNAL"; }
ko()    { echo -e "${ROUGE}  ✗ $*${RAZ}" | tee -a "$JOURNAL"; ECHECS+=("$*"); }

if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être lancé avec sudo : sudo bash $0"
  exit 1
fi

# ---------------------------------------------------------------------
#  Détection du système
# ---------------------------------------------------------------------
. /etc/os-release
DISTRIB="${ID:-inconnu}"            # zorin, ubuntu ou linuxmint
BASE_UBUNTU="${UBUNTU_CODENAME:-${VERSION_CODENAME:-inconnue}}"
case "$DISTRIB" in
  zorin|ubuntu|linuxmint) ;;
  *) echo "Système non prévu : ${PRETTY_NAME:-$DISTRIB}"
     read -rp "Continuer quand même ? (o/N) " rep; [[ "$rep" == [oO] ]] || exit 1 ;;
esac
if [[ "$BASE_UBUNTU" != "noble" ]]; then
  echo "Attention : ce script est prévu pour une base Ubuntu 24.04 (noble)."
  echo "Base détectée : $BASE_UBUNTU (${PRETTY_NAME:-})"
  read -rp "Continuer quand même ? (o/N) " rep; [[ "$rep" == [oO] ]] || exit 1
fi

UTILISATEUR="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
if [[ -z "$UTILISATEUR" || "$UTILISATEUR" == "root" ]]; then
  read -rp "Nom du compte utilisateur·rice principal du poste : " UTILISATEUR
fi
HOME_UTIL="$(getent passwd "$UTILISATEUR" | cut -d: -f6)"
en_tant_que() { sudo -u "$UTILISATEUR" -H "$@"; }

: > "$JOURNAL"
echo "Système : ${PRETTY_NAME:-$DISTRIB} | compte : $UTILISATEUR ($HOME_UTIL)" | tee -a "$JOURNAL"

apt_install() {
  for p in "$@"; do
    if apt-get install -y "$p" >>"$JOURNAL" 2>&1; then ok "$p"; else ko "apt : $p"; fi
  done
}

flatpak_install() {
  # flatpak_install "Nom lisible" id1 [id2 de secours]
  local nom="$1"; shift
  for id in "$@"; do
    if flatpak install -y --noninteractive flathub "$id" >>"$JOURNAL" 2>&1; then
      ok "$nom ($id)"; return 0
    fi
  done
  ko "flatpak : $nom"
}

# Récupère l'URL du dernier fichier publié sur GitHub qui correspond au motif
github_derniere_version() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>>"$JOURNAL" \
    | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 \
    | grep -E "$2" | head -n1
}

deb_depuis_github() {
  # deb_depuis_github "Nom" depot/projet "motif"
  local nom="$1" depot="$2" motif="$3" url fichier
  url="$(github_derniere_version "$depot" "$motif")"
  if [[ -z "$url" ]]; then ko "$nom : fichier introuvable sur GitHub"; return 1; fi
  fichier="/tmp/$(basename "$url")"
  if curl -fsSL -o "$fichier" "$url" && apt-get install -y "$fichier" >>"$JOURNAL" 2>&1; then
    ok "$nom ($(basename "$url"))"
  else
    ko "$nom"
  fi
}

# =====================================================================
titre "1. Mise à jour du système et outils de base"
# =====================================================================
apt-get update >>"$JOURNAL" 2>&1
apt-get -y full-upgrade >>"$JOURNAL" 2>&1 && ok "Système à jour" || ko "Mise à jour système"

apt_install software-properties-common curl wget git unzip p7zip-full \
  python3-venv python3-pip python3-tk flatpak ffmpeg htop

# Logithèque : Zorin et Ubuntu (GNOME) affichent les applis Flatpak via ce
# greffon. Linux Mint gère déjà Flatpak dans sa propre logithèque.
if [[ "$DISTRIB" != "linuxmint" ]]; then
  apt_install gnome-software gnome-software-plugin-flatpak
fi

# Langue française complète (interface, correcteurs, LibreOffice)
apt_install language-pack-fr language-pack-gnome-fr hunspell-fr \
  libreoffice-l10n-fr libreoffice-help-fr

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
  >>"$JOURNAL" 2>&1 && ok "Dépôt Flathub" || ko "Dépôt Flathub"

# =====================================================================
titre "2. Dessin vectoriel : Inkscape + Ink/Stitch + MightyScape (FabLab Chemnitz)"
# =====================================================================
# Inkscape en version .deb récente (pas de snap ni flatpak : Ink/Stitch
# et MightyScape fonctionnent mal avec ces versions)
add-apt-repository -y ppa:inkscape.dev/stable >>"$JOURNAL" 2>&1
apt-get update >>"$JOURNAL" 2>&1
apt_install inkscape

# Ink/Stitch (broderie machine) : dernier .deb officiel
deb_depuis_github "Ink/Stitch" "inkstitch/inkstitch" "amd64\.deb$"

# MightyScape : ~240 extensions du FabLab Chemnitz (découpe laser, boîtes,
# chemins, papercraft...). Menu Extensions > FabLab Chemnitz
EXT_DIR="$HOME_UTIL/.config/inkscape/extensions"
MS_DIR="$EXT_DIR/mightyscape-1.2"
en_tant_que mkdir -p "$EXT_DIR"
if [[ -d "$MS_DIR/.git" ]]; then
  en_tant_que git -C "$MS_DIR" pull >>"$JOURNAL" 2>&1
else
  en_tant_que git clone --depth 1 https://github.com/eridur-de/mightyscape-1.2.git "$MS_DIR" >>"$JOURNAL" 2>&1
fi
if [[ -d "$MS_DIR" ]]; then
  ok "MightyScape téléchargé"
  # Environnement Python dédié, qui garde l'accès aux modules système (inkex)
  en_tant_que python3 -m venv --system-site-packages "$MS_DIR/venv" >>"$JOURNAL" 2>&1
  # Installation ligne par ligne : un module récalcitrant ne bloque pas les autres
  sed '/^#/d;/^\s*$/d' "$MS_DIR/requirements.txt" | while read -r module; do
    en_tant_que "$MS_DIR/venv/bin/pip" install --quiet --no-cache-dir "$module" >>"$JOURNAL" 2>&1 \
      || echo "  (module non installé : $module)" >>"$JOURNAL"
  done
  # Indiquer à Inkscape d'utiliser cet interpréteur Python
  PREFS="$HOME_UTIL/.config/inkscape/preferences.xml"
  if [[ ! -f "$PREFS" ]]; then
    en_tant_que bash -c "cat > '$PREFS'" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<inkscape xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" version="1">
  <group id="extensions" python-interpreter="$MS_DIR/venv/bin/python3" />
</inkscape>
EOF
    ok "Interpréteur Python MightyScape réglé dans Inkscape"
  else
    echo "  Préférences Inkscape existantes : régler à la main Édition > Préférences > Système > Interpréteur Python = $MS_DIR/venv/bin/python3" | tee -a "$JOURNAL"
  fi
else
  ko "MightyScape"
fi

# =====================================================================
titre "3. Découpe laser : xTool Studio (paquet local) + VisiCut"
# =====================================================================
shopt -s nullglob nocaseglob
DEBS_XTOOL=("$DOSSIER_PAQUETS"/*xtool*.deb)
shopt -u nocaseglob
if (( ${#DEBS_XTOOL[@]} )); then
  for deb in "${DEBS_XTOOL[@]}"; do
    if apt-get install -y "$deb" >>"$JOURNAL" 2>&1; then ok "xTool Studio ($(basename "$deb"))"; else ko "xTool Studio ($(basename "$deb"))"; fi
  done
else
  ko "xTool Studio : aucun .deb trouvé dans $DOSSIER_PAQUETS"
fi
shopt -u nullglob

deb_depuis_github "VisiCut" "t-oster/VisiCut" "\.deb$"

# =====================================================================
titre "4. Modélisation 3D et CAO"
# =====================================================================
flatpak_install "FreeCAD"  org.freecad.FreeCAD
flatpak_install "Blender"  org.blender.Blender
apt_install openscad meshlab librecad sweethome3d

# =====================================================================
titre "5. Impression 3D (trancheurs)"
# =====================================================================
flatpak_install "PrusaSlicer" com.prusa3d.PrusaSlicer
flatpak_install "Ultimaker Cura" com.ultimaker.cura
flatpak_install "OrcaSlicer" io.github.orcaslicer.OrcaSlicer io.github.softfever.OrcaSlicer

# =====================================================================
titre "6. Électronique et programmation"
# =====================================================================
flatpak_install "Arduino IDE 2" cc.arduino.IDE2
flatpak_install "KiCad" org.kicad.KiCad
apt_install fritzing thonny esptool picocom

# --- Droits pour Arduino, ESP32, imprimantes 3D et laser en USB ---
# 1. Le compte principal rejoint les groupes d'accès aux ports série
usermod -aG dialout,plugdev "$UTILISATEUR" && ok "$UTILISATEUR ajouté·e aux groupes dialout et plugdev"
# 2. Tout nouveau compte créé plus tard reçoit aussi ces droits
if grep -q '^#\?EXTRA_GROUPS' /etc/adduser.conf; then
  sed -i 's/^#\?EXTRA_GROUPS=.*/EXTRA_GROUPS="dialout plugdev"/; s/^#\?ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/' /etc/adduser.conf
  ok "Nouveaux comptes : droits série automatiques"
fi
# 3. Règle udev : ports série USB accessibles à tou·tes (postes partagés, sessions invité)
cat > /etc/udev/rules.d/99-fablab-serie.rules <<'EOF'
# FabLab Le Boc@l : accès aux cartes Arduino, ESP32, imprimantes 3D, lasers
KERNEL=="ttyACM[0-9]*", MODE="0666", GROUP="dialout"
KERNEL=="ttyUSB[0-9]*", MODE="0666", GROUP="dialout"
# Programmateurs et cartes en mode DFU / bootloader
SUBSYSTEM=="usb", ATTR{idVendor}=="2341", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="2a03", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="10c4", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="303a", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="2e8a", MODE="0666"
EOF
udevadm control --reload-rules && udevadm trigger && ok "Règles udev série USB"
# 4. brltty (lecteur braille) capture les puces CH340 des clones Arduino : on le retire
if dpkg -l brltty 2>/dev/null | grep -q '^ii'; then
  apt-get purge -y brltty >>"$JOURNAL" 2>&1 && ok "brltty retiré (conflit CH340)"
fi

# =====================================================================
titre "7. Graphisme, son, vidéo, mise en page"
# =====================================================================
apt_install gimp krita scribus audacity kdenlive obs-studio \
  fonts-noto fonts-liberation fonts-dejavu fonts-open-sans

# =====================================================================
titre "8. Firefox : page d'accueil et favoris du FabLab"
# =====================================================================
# Favoris rangés en dossiers directement dans la barre personnelle :
# Fraisage CNC, Découpe laser, Impression 3D, FreeCAD, Textile,
# Électronique, Réparation, Réseaux. Ils restent modifiables.
# Navigateur par défaut
# Ubuntu livre Firefox en snap (fichier firefox_firefox.desktop),
# Zorin et Mint en paquet .deb (firefox.desktop)
if command -v snap >/dev/null && snap list firefox >/dev/null 2>&1; then
  FIREFOX_DESKTOP="firefox_firefox.desktop"
else
  FIREFOX_DESKTOP="firefox.desktop"
fi
en_tant_que xdg-settings set default-web-browser "$FIREFOX_DESKTOP" >>"$JOURNAL" 2>&1 || true
# Les réglages (/etc/firefox/policies) sont lus par les versions .deb et snap

POLITIQUE=$(cat <<EOF
{
  "policies": {
    "DisplayBookmarksToolbar": "always",
    "DontCheckDefaultBrowser": true,
    "Homepage": {
      "URL": "${PAGE_ACCUEIL}",
      "Locked": false,
      "StartPage": "homepage"
    },
    "RequestedLocales": [
      "fr"
    ],
    "Bookmarks": [
      {
        "Title": "Le Boc@l",
        "URL": "https://bocal.csc49.fr",
        "Placement": "toolbar"
      },
      {
        "Title": "Fab-Manager",
        "URL": "https://fabmanager.csc49.fr",
        "Placement": "toolbar"
      },
      {
        "Title": "Calcul vitesse et avance (métal, plastiques)",
        "URL": "https://travail-industrie.com/outils/calculateur-parametres-coupe-usinage",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "Calcul avances bois (défonceuse CNC)",
        "URL": "https://www.toolgrit.com/tools/wood-feeds-calc",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "Tableau charges copeaux par matériau",
        "URL": "https://www.cncrouterstore.ca/blogs/news/cnc-chip-load-chart-feeds-speeds-by-material",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "FreeCAD : atelier CAM (fr)",
        "URL": "https://wiki.freecad.org/CAM_Workbench/fr",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "Kiri:Moto (FAO en ligne)",
        "URL": "https://grid.space/kiri/",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "NC Viewer (visualiser un G-code)",
        "URL": "https://ncviewer.com",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "CAMotics (simulation d'usinage)",
        "URL": "https://camotics.org",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "Universal G-code Sender",
        "URL": "https://winder.github.io/ugs_website/",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "Wiki grblHAL",
        "URL": "https://github.com/grblHAL/core/wiki",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "Forum Usinages.com",
        "URL": "https://www.usinages.com",
        "Placement": "toolbar",
        "Folder": "Fraisage CNC"
      },
      {
        "Title": "Boxes.py (générateur de boîtes)",
        "URL": "https://festi.info/boxes.py/",
        "Placement": "toolbar",
        "Folder": "Découpe laser"
      },
      {
        "Title": "MakerCase",
        "URL": "https://www.makercase.com",
        "Placement": "toolbar",
        "Folder": "Découpe laser"
      },
      {
        "Title": "Doc MightyScape (FabLab Chemnitz)",
        "URL": "https://y.stadtfabrikanten.org/mightyscape-overview",
        "Placement": "toolbar",
        "Folder": "Découpe laser"
      },
      {
        "Title": "VisiCut",
        "URL": "https://visicut.org",
        "Placement": "toolbar",
        "Folder": "Découpe laser"
      },
      {
        "Title": "Support xTool",
        "URL": "https://support.xtool.com",
        "Placement": "toolbar",
        "Folder": "Découpe laser"
      },
      {
        "Title": "Printables",
        "URL": "https://www.printables.com",
        "Placement": "toolbar",
        "Folder": "Impression 3D"
      },
      {
        "Title": "Thingiverse",
        "URL": "https://www.thingiverse.com",
        "Placement": "toolbar",
        "Folder": "Impression 3D"
      },
      {
        "Title": "MyMiniFactory",
        "URL": "https://www.myminifactory.com",
        "Placement": "toolbar",
        "Folder": "Impression 3D"
      },
      {
        "Title": "Cults3D",
        "URL": "https://cults3d.com/fr",
        "Placement": "toolbar",
        "Folder": "Impression 3D"
      },
      {
        "Title": "Thangs (moteur de recherche 3D)",
        "URL": "https://thangs.com",
        "Placement": "toolbar",
        "Folder": "Impression 3D"
      },
      {
        "Title": "Tinkercad",
        "URL": "https://www.tinkercad.com",
        "Placement": "toolbar",
        "Folder": "Impression 3D"
      },
      {
        "Title": "Aide Prusa (réglages, défauts d'impression)",
        "URL": "https://help.prusa3d.com/fr",
        "Placement": "toolbar",
        "Folder": "Impression 3D"
      },
      {
        "Title": "Guide FreeCAD Lachiver (fr)",
        "URL": "${LIEN_TUTOS_LACHIVER}",
        "Placement": "toolbar",
        "Folder": "FreeCAD"
      },
      {
        "Title": "Wiki FreeCAD (fr)",
        "URL": "https://wiki.freecad.org/Main_Page/fr",
        "Placement": "toolbar",
        "Folder": "FreeCAD"
      },
      {
        "Title": "Tutoriels vidéo (wiki FreeCAD)",
        "URL": "https://wiki.freecad.org/Video_tutorials",
        "Placement": "toolbar",
        "Folder": "FreeCAD"
      },
      {
        "Title": "Forum FreeCAD francophone",
        "URL": "https://forum.freecad.org/viewforum.php?f=12",
        "Placement": "toolbar",
        "Folder": "FreeCAD"
      },
      {
        "Title": "Ink/Stitch (doc en français)",
        "URL": "https://inkstitch.org/fr/",
        "Placement": "toolbar",
        "Folder": "Textile"
      },
      {
        "Title": "Seamly2D (patronage)",
        "URL": "https://seamly.io",
        "Placement": "toolbar",
        "Folder": "Textile"
      },
      {
        "Title": "Docs Arduino",
        "URL": "https://docs.arduino.cc",
        "Placement": "toolbar",
        "Folder": "Électronique"
      },
      {
        "Title": "Wokwi (simulateur)",
        "URL": "https://wokwi.com",
        "Placement": "toolbar",
        "Folder": "Électronique"
      },
      {
        "Title": "Vittascience",
        "URL": "https://fr.vittascience.com",
        "Placement": "toolbar",
        "Folder": "Électronique"
      },
      {
        "Title": "Scratch",
        "URL": "https://scratch.mit.edu",
        "Placement": "toolbar",
        "Folder": "Électronique"
      },
      {
        "Title": "MicroPython",
        "URL": "https://micropython.org",
        "Placement": "toolbar",
        "Folder": "Électronique"
      },
      {
        "Title": "iFixit (fr)",
        "URL": "https://fr.ifixit.com",
        "Placement": "toolbar",
        "Folder": "Réparation"
      },
      {
        "Title": "Repair Café",
        "URL": "https://www.repaircafe.org/fr/",
        "Placement": "toolbar",
        "Folder": "Réparation"
      },
      {
        "Title": "Longue vie aux objets (ADEME)",
        "URL": "https://longuevieauxobjets.ademe.fr",
        "Placement": "toolbar",
        "Folder": "Réparation"
      },
      {
        "Title": "Réseau Français des Fablabs",
        "URL": "https://www.fablab.fr",
        "Placement": "toolbar",
        "Folder": "Réseaux"
      },
      {
        "Title": "Fablabs.io",
        "URL": "https://www.fablabs.io",
        "Placement": "toolbar",
        "Folder": "Réseaux"
      },
      {
        "Title": "Low-tech Lab",
        "URL": "https://lowtechlab.org",
        "Placement": "toolbar",
        "Folder": "Réseaux"
      },
      {
        "Title": "Framasoft",
        "URL": "https://framasoft.org",
        "Placement": "toolbar",
        "Folder": "Réseaux"
      }
    ]
  }
}
EOF
)
for d in /etc/firefox/policies /usr/lib/firefox/distribution; do
  if [[ "$d" == /etc/* || -d "$(dirname "$d")" ]]; then
    mkdir -p "$d" && echo "$POLITIQUE" > "$d/policies.json"
  fi
done
ok "Firefox : accueil $PAGE_ACCUEIL, dossiers Fraisage CNC, Découpe laser, Impression 3D... dans la barre personnelle"

# =====================================================================
titre "9. Nettoyage"
# =====================================================================
apt-get -y autoremove >>"$JOURNAL" 2>&1
flatpak update -y --noninteractive >>"$JOURNAL" 2>&1
ok "Terminé"

# =====================================================================
echo
if (( ${#ECHECS[@]} )); then
  echo -e "${ROUGE}Éléments à reprendre à la main :${RAZ}"
  printf '  - %s\n' "${ECHECS[@]}"
else
  echo -e "${VERT}Tout s'est installé correctement.${RAZ}"
fi
echo
echo "Journal complet : $JOURNAL"
echo "Pensez à redémarrer le poste : droits Arduino, et applis Flatpak visibles dans le menu."
