#!/bin/bash
# ============================================================
#  install-mightyscape.sh
#  Installation de MightyScape (extensions FabLab Chemnitz)
#  pour Inkscape sur Ubuntu/Debian — Boc@l FabLab
# ============================================================

set -e

NF="\033[0m"
CL="\033[38;5;45m"
CR="\033[38;5;196m"
CG="\033[38;5;82m"
CY="\033[38;5;226m"

info()    { echo -e "${CL}[INFO]${NF} $*"; }
success() { echo -e "${CG}[ OK ]${NF} $*"; }
warn()    { echo -e "${CY}[WARN]${NF} $*"; }
error()   { echo -e "${CR}[ERR ]${NF} $*"; }

echo -e "${CL}"
echo "  __  ____      __   __       ____                  "
echo " /  |/  (_)__ _/ /  / /___ __/ __/______ ____  ___  "
echo "/ /|_/ / / _ \`/ _ \/ __/ // /\ \/ __/ _ \`/ _ \/ -_)"
echo "/_/  /_/_/\_, /_//_/\__/\_, /___/\__/\_,_/ .__/\__/ "
echo "         /___/         /___/            /_/          "
echo -e "${NF}"
echo -e "${CL}MightyScape — Collection d'extensions FabLab Chemnitz pour Inkscape${NF}"
echo -e "${CL}Script d'installation — Boc\@l FabLab Chemillé${NF}\n"

# ------------------------------------------------------------
# 1. Vérifications préalables
# ------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    error "Ne pas exécuter en root. Relancez sans sudo."
    exit 1
fi

# Détection d'Inkscape Flatpak
INKSCAPE_FLATPAK_ID="org.inkscape.Inkscape"
if ! flatpak list 2>/dev/null | grep -q "$INKSCAPE_FLATPAK_ID"; then
    error "Inkscape Flatpak (${INKSCAPE_FLATPAK_ID}) non trouvé."
    error "Installez-le d'abord : flatpak install flathub ${INKSCAPE_FLATPAK_ID}"
    exit 1
fi

INKSCAPE_USER_DIR=$(flatpak run "$INKSCAPE_FLATPAK_ID" --user-data-directory 2>/dev/null)
EXTENSIONS_DIR="$INKSCAPE_USER_DIR/extensions"
MIGHTYSCAPE_DIR="$EXTENSIONS_DIR/mightyscape-1.2"
PREF_FILE="$INKSCAPE_USER_DIR/preferences.xml"

info "Répertoire Inkscape : $INKSCAPE_USER_DIR"
info "Répertoire extensions : $EXTENSIONS_DIR"

# Vérifier qu'Inkscape n'est pas en cours d'exécution
if pgrep -x "inkscape" > /dev/null 2>&1; then
    error "Inkscape est en cours d'exécution. Fermez-le avant de continuer."
    exit 1
fi

# ------------------------------------------------------------
# 2. Dépendances système
# ------------------------------------------------------------

info "Installation des dépendances système..."

PACKAGES=(
    git                 # Clonage et mise à jour de MightyScape
    cmake               # Compilation d'openmesh (maillages 3D)
    ninja-build         # Backend de compilation pour openmesh
    python3.10          # Python 3.10 requis par le venv MightyScape
    python3.10-dev      # Headers C pour compiler openmesh
    python3.10-venv     # Module venv pour Python 3.10
    curl                # Téléchargement de l'installeur uv
    libgirepository-2.0-dev  # Bindings GObject (utilisé par certaines extensions)
    xmlstarlet          # Édition du preferences.xml (optionnel)
)

sudo apt-get update -qq
sudo apt-get install -y "${PACKAGES[@]}"
success "Dépendances système installées."

# ------------------------------------------------------------
# 3. Installeur de paquets Python : uv
# ------------------------------------------------------------

if ! command -v uv &>/dev/null && [[ ! -f "$HOME/.local/bin/uv" ]]; then
    info "Installation de uv (gestionnaire de paquets Python ultrarapide)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
UV="${HOME}/.local/bin/uv"
[[ ! -f "$UV" ]] && UV="$(command -v uv)"
success "uv disponible : $($UV --version)"

# ------------------------------------------------------------
# 4. Clonage de MightyScape
# ------------------------------------------------------------

mkdir -p "$EXTENSIONS_DIR"

if [[ -d "$MIGHTYSCAPE_DIR/.git" ]]; then
    info "MightyScape déjà présent — mise à jour..."
    git -C "$MIGHTYSCAPE_DIR" pull
else
    info "Clonage de MightyScape depuis GitHub..."
    git clone --depth=1 https://github.com/eridur-de/mightyscape-1.2.git "$MIGHTYSCAPE_DIR"
fi
success "MightyScape cloné dans $MIGHTYSCAPE_DIR"

# ------------------------------------------------------------
# 5. Environnement virtuel Python
# ------------------------------------------------------------

info "Création de l'environnement virtuel Python 3.10..."
export UV_PROJECT_ENVIRONMENT="$MIGHTYSCAPE_DIR"
"$UV" venv --python python3.10 --allow-existing "$MIGHTYSCAPE_DIR"
PYTHON="$MIGHTYSCAPE_DIR/bin/python3"
success "Venv créé : $("$PYTHON" --version)"

# ------------------------------------------------------------
# 6. Paquets Python — installation par catégorie
# ------------------------------------------------------------

info "Installation des paquets Python (peut prendre quelques minutes)..."

# --- Traitement d'image (Pillow) ---
# Requis par : export_selection_as, image_triangulation, imagetracerjs,
#   kvec, laser_check, low_poly_2, ocr, pixel2svg, pixels2objects,
#   primitive, raster_perspective, webp_import
"$UV" pip install --python "$PYTHON" Pillow

# --- Calcul scientifique ---
# numpy      : base de nombreuses extensions (hatch_fill, netting, spirograph…)
# scikit-learn : color_harmony (analyse de couleurs, clustering)
"$UV" pip install --python "$PYTHON" numpy scikit-learn

# --- Traitement de graphes ---
# networkx : paperfold (construction du graphe de dépliage de maillage)
"$UV" pip install --python "$PYTHON" networkx

# --- Maillages 3D (nécessite python3.10-dev + cmake) ---
# openmesh : import_3d_mesh, paperfold, slic3r_stl_input
#   → bibliothèque C++ de manipulation de maillages polygonaux
#   → compilation depuis les sources (~90 secondes)
info "Compilation d'openmesh (bibliothèque C++ de maillages 3D — ~90s)..."
"$UV" pip install --python "$PYTHON" pybind11 openmesh

# --- Rendu 3D / Papercraft ---
# pygame   : papercraft_unfold (affichage du modèle 3D pendant le dépliage)
# PyOpenGL : papercraft_unfold (rendu OpenGL du modèle 3D)
"$UV" pip install --python "$PYTHON" pygame PyOpenGL

# --- Lancer de rayons (simulation optique) ---
# raytracing : extension raytracing (simulation de chemins optiques dans Inkscape)
"$UV" pip install --python "$PYTHON" raytracing

# --- Gestion de version (mise à jour MightyScape depuis Inkscape) ---
# GitPython : about_upgrade_mightyscape (bouton "Mettre à jour" dans Inkscape)
"$UV" pip install --python "$PYTHON" GitPython

# --- Interface Qt ---
# PyQt5 : output_pro (export avancé multi-format avec interface graphique Qt)
"$UV" pip install --python "$PYTHON" PyQt5

# --- Traitement de chemin de découpe laser ---
# vpype   : vpypetools (optimisation de chemins pour traceur/découpe laser)
# trimesh : extensions de traitement de maillages légers
"$UV" pip install --python "$PYTHON" vpype trimesh

# --- Formats de données géographiques / vectoriels ---
# lxml : (déjà inclus dans inkex, mais requis explicitement par plusieurs extensions)
"$UV" pip install --python "$PYTHON" lxml

# --- Autres requirements.txt des extensions ---
info "Installation des dépendances restantes depuis les requirements.txt..."
find "$MIGHTYSCAPE_DIR/extensions/fablabchemnitz" -name "requirements.txt" \
    -exec sh -c '"$1" pip install --python "$2" -r "$3" 2>/dev/null || true' \
    _ "$UV" "$PYTHON" {} \;

success "Tous les paquets Python installés."

# ------------------------------------------------------------
# 7. Configuration d'Inkscape (python-interpreter)
# ------------------------------------------------------------

info "Configuration du Python MightyScape dans Inkscape..."

if [[ ! -f "$PREF_FILE" ]]; then
    warn "preferences.xml introuvable — lancez Inkscape une première fois, puis relancez ce script."
else
    PREF_VALUE="$MIGHTYSCAPE_DIR/bin/python3"
    if grep -q "python-interpreter" "$PREF_FILE"; then
        sed -i "s|python-interpreter=\"[^\"]*\"|python-interpreter=\"$PREF_VALUE\"|" "$PREF_FILE"
    else
        sed -i "s|id=\"extensions\"|id=\"extensions\"\n     python-interpreter=\"$PREF_VALUE\"|" "$PREF_FILE"
    fi
    success "Python configuré dans preferences.xml : $PREF_VALUE"
fi

# ------------------------------------------------------------
# 8. Résumé
# ------------------------------------------------------------

echo ""
echo -e "${CG}╔══════════════════════════════════════════════════════╗${NF}"
echo -e "${CG}║     Installation MightyScape terminée !              ║${NF}"
echo -e "${CG}╚══════════════════════════════════════════════════════╝${NF}"
echo ""
echo -e "  Extensions installées : ${CL}$MIGHTYSCAPE_DIR/extensions/fablabchemnitz/${NF}"
echo -e "  Python utilisé        : ${CL}$("$PYTHON" --version)${NF}"
echo -e "  Nombre d'extensions   : ${CL}$(ls "$MIGHTYSCAPE_DIR/extensions/fablabchemnitz/" | wc -l)${NF}"
echo ""
echo -e "  ${CY}Relancez Inkscape — toutes les extensions apparaissent${NF}"
echo -e "  ${CY}dans le menu : Extensions → FabLab Chemnitz${NF}"
echo ""
