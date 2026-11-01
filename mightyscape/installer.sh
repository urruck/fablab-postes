#!/bin/bash
# =====================================================================
#  Extensions Inkscape « FabLab Boc@l » (MightyScape trié et traduit)
#  À lancer en tant qu'utilisateur (pas en root) :
#      bash mightyscape/installer.sh
#  Option : --source DOSSIER  pour utiliser un clone local de mightyscape-1.2
#           (installation sans accès à GitHub).
#
#  1. récupère MightyScape à la version testée (MIGHTYSCAPE_COMMIT) ;
#  2. construit le dossier extensions/fablab-bocal (construire.py) :
#     extensions retenues seulement, corrigées, traduites, menus rangés ;
#  3. installe les bibliothèques Python pour le Python d'Inkscape Flatpak ;
#  4. retire l'ancienne installation mightyscape-1.2 (mise de côté).
# =====================================================================
set -u

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGHTYSCAPE_DEPOT="https://github.com/eridur-de/mightyscape-1.2.git"
MIGHTYSCAPE_COMMIT="e7e6cdb43a95f59667488cfb804a86a9cd44aee3"   # 22/08/2026, testé avec Inkscape 1.4 Flatpak
FLATPAK_ID="org.inkscape.Inkscape"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/fablab-bocal"

info() { echo -e "\033[38;5;45m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[38;5;82m[ OK ]\033[0m $*"; }
warn() { echo -e "\033[38;5;226m[WARN]\033[0m $*"; }
err()  { echo -e "\033[38;5;196m[ERR ]\033[0m $*"; exit 1; }

SOURCE=""
[[ "${1:-}" == "--source" ]] && SOURCE="${2:-}"

[[ $EUID -eq 0 ]] && err "Ne pas lancer en root : les extensions s'installent dans le compte de l'utilisateur."
flatpak info "$FLATPAK_ID" >/dev/null 2>&1 || err "Inkscape Flatpak absent : flatpak install flathub $FLATPAK_ID"
pgrep -u "$USER" -x inkscape >/dev/null && err "Inkscape est ouvert : fermez-le puis relancez."
command -v python3 >/dev/null || err "python3 introuvable."

INK_DIR="$HOME/.var/app/$FLATPAK_ID/config/inkscape"
EXT_DIR="$INK_DIR/extensions"
CIBLE="$EXT_DIR/fablab-bocal"
mkdir -p "$EXT_DIR" "$CACHE"

# ---------------------------------------------------------------------
# 1. MightyScape à la version testée
# ---------------------------------------------------------------------
if [[ -z "$SOURCE" ]]; then
  SOURCE="$CACHE/mightyscape-1.2"
  command -v git >/dev/null || err "git introuvable (sudo apt install git)."
  if [[ "$(git -C "$SOURCE" rev-parse HEAD 2>/dev/null)" != "$MIGHTYSCAPE_COMMIT" ]]; then
    info "Téléchargement de MightyScape ($MIGHTYSCAPE_COMMIT)..."
    rm -rf "$SOURCE" && git init -q "$SOURCE" \
      && git -C "$SOURCE" fetch -q --depth 1 "$MIGHTYSCAPE_DEPOT" "$MIGHTYSCAPE_COMMIT" \
      && git -C "$SOURCE" checkout -q FETCH_HEAD \
      || err "Téléchargement de MightyScape impossible."
  fi
fi
[[ -d "$SOURCE/extensions/fablabchemnitz" ]] || err "$SOURCE/extensions/fablabchemnitz introuvable."
ok "MightyScape : $SOURCE"

# ---------------------------------------------------------------------
# 2. Construction du dossier fablab-bocal
# ---------------------------------------------------------------------
info "Tri, corrections et traduction des extensions..."
TEMP="$EXT_DIR/.fablab-bocal.nouveau"
python3 "$ICI/construire.py" "$SOURCE/extensions/fablabchemnitz" "$TEMP" || err "Construction impossible."
rm -rf "$CIBLE" && mv "$TEMP" "$CIBLE"
ok "Extensions installées : $CIBLE"

# ---------------------------------------------------------------------
# 3. Bibliothèques Python, pour le Python d'Inkscape Flatpak
#    (dossier ~/.var/app/org.inkscape.Inkscape/data/python, lu par Inkscape)
# ---------------------------------------------------------------------
PYV="$(flatpak run --command=python3 "$FLATPAK_ID" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)"
[[ -n "$PYV" ]] || err "Python d'Inkscape introuvable."
SITE="$HOME/.var/app/$FLATPAK_ID/data/python/lib/python$PYV/site-packages"

UV="$(command -v uv || echo "$HOME/.local/bin/uv")"
if [[ ! -x "$UV" ]]; then
  info "Installation de uv (installeur de paquets Python)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null || err "Installation de uv impossible."
  UV="$HOME/.local/bin/uv"
fi

info "Bibliothèques Python pour Python $PYV (quelques minutes)..."
TMP_SITE="$CACHE/site-$PYV"
rm -rf "$TMP_SITE"
"$UV" pip install -q --target "$TMP_SITE" --python-version "$PYV" \
  --python-platform x86_64-manylinux_2_28 -r "$ICI/dependances.txt" \
  || err "Installation des bibliothèques Python impossible."
# numpy, Pillow et lxml sont fournis par Inkscape : ne pas les doubler
( cd "$TMP_SITE" && rm -rf numpy numpy-* numpy.libs PIL pillow-* pillow.libs lxml lxml-* bin )
mkdir -p "$SITE" && cp -a "$TMP_SITE/." "$SITE/" && rm -rf "$TMP_SITE"
flatpak run --command=python3 "$FLATPAK_ID" -c \
  'import boxes, vpype, vpype_occult, scipy, shapely, svgpathtools, networkx, pyclipper, ezdxf, cv2' \
  >/dev/null 2>&1 && ok "Bibliothèques Python : $SITE" || warn "Certaines bibliothèques ne se chargent pas dans Inkscape."

# ---------------------------------------------------------------------
# 4. Ancienne installation mightyscape-1.2 (même menu, en double)
# ---------------------------------------------------------------------
if [[ -d "$EXT_DIR/mightyscape-1.2" ]]; then
  ANCIEN="$CACHE/ancien-mightyscape-1.2-$(date +%Y%m%d-%H%M%S)"
  mv "$EXT_DIR/mightyscape-1.2" "$ANCIEN" && ok "Ancien MightyScape mis de côté : $ANCIEN (supprimable)"
fi
# L'ancien script réglait Inkscape sur un Python 3.10 hors Flatpak, inutilisable : on l'enlève
PREFS="$INK_DIR/preferences.xml"
if [[ -f "$PREFS" ]] && grep -q 'python-interpreter="[^"]*mightyscape' "$PREFS"; then
  sed -i 's| python-interpreter="[^"]*mightyscape[^"]*"||' "$PREFS" && ok "Interpréteur Python d'Inkscape remis par défaut"
fi

echo
ok "Terminé : relancez Inkscape, menu Extensions > FabLab Boc@l"
