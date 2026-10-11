#!/usr/bin/env bash
# =====================================================================
#  Installation d'un poste FabLab Le Boc@l (CSC du Chemillois)
#  Cibles : Zorin OS 18, Ubuntu 24.04 LTS, Linux Mint 22.x
#  (toutes basées sur Ubuntu 24.04 "noble"), installation neuve
#  Le script détecte le système et s'adapte tout seul.
#
#  Usage :
#    1. Récupérer le dépôt : git clone https://github.com/urruck/fablab-postes.git
#       (xTool Studio est téléchargé tout seul depuis le cloud du CSC ;
#       un .deb déposé dans "paquets/" est utilisé en priorité)
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

# Partage Nextcloud du CSC contenant les .deb de xTool Studio pour Linux.
# Le script y prend automatiquement la version la plus récente.
XTOOL_PARTAGE="https://cloud.csc49.fr/index.php/s/6FxRn57Lnpda7ds"

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
  python3-venv python3-pip python3-tk flatpak ffmpeg htop \
  python3.10 python3.10-dev python3.10-venv \
  cmake ninja-build

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
titre "2. Dessin vectoriel : Inkscape + Ink/Stitch + MightyScape (FabLab Boc@l)"
# =====================================================================
# Inkscape via Flatpak : mises à jour automatiques, compatible MightyScape
# et Ink/Stitch (testé sur Flatpak 1.4+).
flatpak_install "Inkscape" org.inkscape.Inkscape

# Ink/Stitch (broderie machine) : installé dans le répertoire d'extensions Flatpak
INKSTITCH_URL="$(github_derniere_version "inkstitch/inkstitch" "linux\.sh$")"
if [[ -n "$INKSTITCH_URL" ]]; then
  INKSTITCH_SH="/tmp/inkstitch-install.sh"
  curl -fsSL -o "$INKSTITCH_SH" "$INKSTITCH_URL" >>"$JOURNAL" 2>&1
  chmod +x "$INKSTITCH_SH"
  en_tant_que bash "$INKSTITCH_SH" >>"$JOURNAL" 2>&1 && ok "Ink/Stitch" || ko "Ink/Stitch"
  rm -f "$INKSTITCH_SH"
else
  deb_depuis_github "Ink/Stitch" "inkstitch/inkstitch" "amd64\.deb$"
fi

# ------------------------------------------------------------------
# MightyScape : ~240 extensions Boc@l (découpe laser, boîtes, tracés,
# papercraft, 3D...). Menu Inkscape : Extensions > FabLab Boc@l
# ------------------------------------------------------------------

# Chemin extensions : Flatpak si disponible, sinon apt
if flatpak list 2>/dev/null | grep -q "org.inkscape.Inkscape"; then
  INK_USER_DIR="$(en_tant_que flatpak run org.inkscape.Inkscape --user-data-directory 2>/dev/null)"
  EXT_DIR="${INK_USER_DIR}/extensions"
else
  EXT_DIR="$HOME_UTIL/.config/inkscape/extensions"
fi
MS_DIR="$EXT_DIR/mightyscape-1.2"

en_tant_que mkdir -p "$EXT_DIR"
if [[ -d "$MS_DIR/.git" ]]; then
  en_tant_que git -C "$MS_DIR" pull >>"$JOURNAL" 2>&1 && ok "MightyScape mis à jour"
else
  en_tant_que git clone --depth 1 https://github.com/eridur-de/mightyscape-1.2.git "$MS_DIR" \
    >>"$JOURNAL" 2>&1 && ok "MightyScape cloné"
fi

if [[ ! -d "$MS_DIR" ]]; then
  ko "MightyScape : clonage impossible";
else

  # Personnalisation Boc@l : renommer le sous-menu et supprimer color_harmony
  # (dépend de PyQt4 obsolète)
  find "$MS_DIR/extensions/fablabchemnitz" -name "*.inx" \
    -exec sed -i 's/FabLab Chemnitz/FabLab Boc@l/g' {} \; >>"$JOURNAL" 2>&1
  rm -rf "$MS_DIR/extensions/fablabchemnitz/color_harmony"
  ok "MightyScape : sous-menu renommé FabLab Boc@l, color_harmony retiré"

  # Correction admesh : le wrapper libtool a un chemin LD_LIBRARY_PATH codé en
  # dur avec le chemin du développeur original (/home/tomate/...). On le
  # remplace par $progdir calculé dynamiquement, sans quoi papercraft_unfold
  # échoue avec "libadmesh.so.1: cannot open shared object file".
  ADMESH_WRAPPER="$MS_DIR/extensions/fablabchemnitz/papercraft_unfold/admesh/linux/admesh"
  sed -i 's|LD_LIBRARY_PATH="/home/tomate/mightyscape/papercraft_unfold/admesh/linux/.libs:|LD_LIBRARY_PATH="$progdir:|' \
    "$ADMESH_WRAPPER" >>"$JOURNAL" 2>&1 && ok "admesh : chemin LD_LIBRARY_PATH corrigé"

  # Correction papercraft_unfold.py :
  # 1. fstl : prévisualisation Qt5 ignorée si Qt5 absent (sandbox Flatpak)
  # 2. bounding_box : try/except pour incompatibilité API inkex 1.4 (_Element lxml brut)
  PU="$MS_DIR/extensions/fablabchemnitz/papercraft_unfold/papercraft_unfold.py"
  python3 - "$PU" >>"$JOURNAL" 2>&1 <<'PYFIX'
import sys
path = sys.argv[1]
src = open(path).read()
old  = '            p = Popen(fstl_cmd, shell=True)\n            p.wait()'
new  = '            try:\n                p = Popen(fstl_cmd, shell=True, stderr=PIPE)\n                p.wait()\n                if p.returncode != 0:\n                    inkex.utils.debug("fstl viewer unavailable (Qt5 missing?) \xe2\x80\x94 skipping preview")\n            except Exception:\n                pass'
old2 = '            bbox = inkex.elements._selected.ElementList.bounding_box(doc)'
new2 = '            try:\n                bbox = inkex.elements._selected.ElementList.bounding_box(doc)\n            except (ValueError, AttributeError, TypeError):\n                bbox = None'
if old in src:  src = src.replace(old, new)
if old2 in src: src = src.replace(old2, new2)
open(path, 'w').write(src)
PYFIX
  ok "papercraft_unfold.py : fstl et bounding_box corrigés"

  # uv : gestionnaire Python rapide (installé en tant qu'utilisateur)
  if [[ ! -f "$HOME_UTIL/.local/bin/uv" ]]; then
    en_tant_que bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' >>"$JOURNAL" 2>&1
  fi
  UV_CMD="$HOME_UTIL/.local/bin/uv"

  # Environnement virtuel Python 3.10 isolé dans le dossier MightyScape
  # (python3.10-dev et cmake sont requis pour compiler openmesh)
  en_tant_que bash -c "
    export UV_PROJECT_ENVIRONMENT='$MS_DIR'
    '$UV_CMD' venv --python python3.10 --allow-existing '$MS_DIR'
  " >>"$JOURNAL" 2>&1
  PYTHON="$MS_DIR/bin/python3"

  ms_pip() {
    en_tant_que "$UV_CMD" pip install --python "$PYTHON" "$@" >>"$JOURNAL" 2>&1 \
      && ok "Python: $*" || ko "Python: $*"
  }

  # Traitement d'image : export_selection_as, image_triangulation, kvec,
  #   laser_check, low_poly_2, ocr, pixel2svg, pixels2objects, primitive,
  #   raster_perspective, webp_import, imagetracerjs
  ms_pip Pillow

  # Calcul numérique (base de la quasi-totalité des extensions de tracé)
  ms_pip numpy

  # Analyse couleurs par clustering (color_harmony core → conservé pour usage futur)
  ms_pip scikit-learn

  # Graphes : paperfold (spanning tree pour le dépliage de maillages 3D)
  ms_pip networkx

  # Maillages 3D C++ : import_3d_mesh, paperfold, slic3r_stl_input
  # → nécessite python3.10-dev + cmake + ninja-build pour compiler depuis les sources
  echo "  Compilation openmesh (~90s)..." | tee -a "$JOURNAL"
  ms_pip pybind11 openmesh

  # Rendu 3D interactif : papercraft_unfold (prévisualisation OpenGL du modèle)
  ms_pip pygame PyOpenGL

  # Simulation optique : extension raytracing (lancer de rayons paraxial)
  ms_pip raytracing

  # Mise à jour MightyScape depuis Inkscape (bouton Upgrade MightyScape)
  ms_pip GitPython

  # Export multi-format avec interface Qt : output_pro
  ms_pip PyQt5

  # Optimisation de tracés vectoriels pour découpeuse laser / traceur
  ms_pip vpype trimesh lxml

  # Dépendances restantes des requirements.txt individuels (best-effort)
  find "$MS_DIR/extensions/fablabchemnitz" -name "requirements.txt" | while read -r req; do
    en_tant_que "$UV_CMD" pip install --python "$PYTHON" -r "$req" >>"$JOURNAL" 2>&1 || true
  done
  ok "MightyScape : dépendances Python installées"

  # Configurer Inkscape pour utiliser le Python du venv MightyScape
  PREFS="${INK_USER_DIR:-$HOME_UTIL/.config/inkscape}/preferences.xml"
  PREF_VALUE="$MS_DIR/bin/python3"
  if [[ ! -f "$PREFS" ]]; then
    en_tant_que mkdir -p "$(dirname "$PREFS")"
    en_tant_que bash -c "cat > '$PREFS'" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<inkscape version="1">
  <group id="extensions" python-interpreter="$PREF_VALUE" />
</inkscape>
EOF
    ok "Interpréteur Python MightyScape réglé dans Inkscape"
  elif grep -q "python-interpreter" "$PREFS"; then
    sed -i "s|python-interpreter=\"[^\"]*\"|python-interpreter=\"$PREF_VALUE\"|" "$PREFS"
    ok "Interpréteur Python MightyScape mis à jour dans Inkscape"
  else
    sed -i "s|id=\"extensions\"|id=\"extensions\" python-interpreter=\"$PREF_VALUE\"|" "$PREFS"
    ok "Interpréteur Python MightyScape ajouté dans Inkscape"
  fi

fi

# =====================================================================
titre "3. Découpe laser : xTool Studio + VisiCut"
# =====================================================================
# xTool Studio n'est pas dans les dépôts : on prend d'abord un .deb déposé
# dans paquets/, sinon on télécharge la version la plus récente depuis le
# partage Nextcloud du CSC (XTOOL_PARTAGE, en haut du script).
xtool_telecharger() {
  local base jeton liste fichier url
  base="${XTOOL_PARTAGE%%/index.php/s/*}"; base="${base%%/s/*}"
  jeton="${XTOOL_PARTAGE##*/s/}"; jeton="${jeton%%[/?]*}"
  mkdir -p "$DOSSIER_PAQUETS"
  # 1. Lister les .deb du partage (WebDAV public de Nextcloud, ancienne puis nouvelle adresse)
  for dav in "$base/public.php/webdav/" "$base/public.php/dav/files/$jeton/"; do
    liste="$(curl -fsS -m 30 -X PROPFIND -H "Depth: 1" -u "$jeton:" "$dav" 2>>"$JOURNAL" \
      | grep -oiE '<d:href>[^<]+\.deb</d:href>' | sed -E 's#</?d:href>##g')"
    [[ -n "$liste" ]] || continue
    # Garder les paquets xTool si le dossier en contient d'autres, puis la version la plus haute
    if grep -qi xtool <<<"$liste"; then liste="$(grep -i xtool <<<"$liste")"; fi
    url="$base$(sort -V <<<"$liste" | tail -n1)"
    fichier="$DOSSIER_PAQUETS/$(basename "$url" | sed 's/%20/_/g')"
    echo "  Téléchargement de $(basename "$fichier")..." | tee -a "$JOURNAL" >&2
    if curl -fL -m 1800 --retry 2 -u "$jeton:" -o "$fichier" "$url" 2>>"$JOURNAL"; then
      echo "$fichier"; return 0
    fi
    rm -f "$fichier"
  done
  # 2. Secours : télécharger tout le dossier en zip et prendre le .deb le plus récent
  local zip="$DOSSIER_PAQUETS/xtool-partage.zip"
  echo "  Téléchargement du dossier partagé complet (zip)..." | tee -a "$JOURNAL" >&2
  if curl -fL -m 3600 --retry 2 -o "$zip" "$base/index.php/s/$jeton/download" 2>>"$JOURNAL" \
     && unzip -oj -qq "$zip" '*.deb' -d "$DOSSIER_PAQUETS" >>"$JOURNAL" 2>&1; then
    rm -f "$zip"
    find "$DOSSIER_PAQUETS" -maxdepth 1 -iname '*.deb' | sort -V | tail -n1
    return 0
  fi
  rm -f "$zip"
  return 1
}

shopt -s nullglob nocaseglob
DEBS_XTOOL=("$DOSSIER_PAQUETS"/*xtool*.deb)
shopt -u nocaseglob nullglob
if (( ${#DEBS_XTOOL[@]} )); then
  DEB_XTOOL="$(printf '%s\n' "${DEBS_XTOOL[@]}" | sort -V | tail -n1)"
  echo "  Paquet xTool local trouvé : $(basename "$DEB_XTOOL")" | tee -a "$JOURNAL"
else
  DEB_XTOOL="$(xtool_telecharger | tail -n1)"
fi
if [[ -n "${DEB_XTOOL:-}" && -f "$DEB_XTOOL" ]]; then
  if apt-get install -y "$DEB_XTOOL" >>"$JOURNAL" 2>&1; then
    ok "xTool Studio ($(basename "$DEB_XTOOL"))"
  else
    ko "xTool Studio : échec d'installation de $(basename "$DEB_XTOOL")"
  fi
else
  ko "xTool Studio : téléchargement impossible depuis $XTOOL_PARTAGE (déposer le .deb dans paquets/)"
fi

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
        "Title": "Doc MightyScape (FabLab Boc@l)",
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
