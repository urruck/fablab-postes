# xtool-p2 — Pilotage open-source de la xTool P2 sous Linux

Outil CLI en Rust pour détecter, analyser et piloter la **xTool P2** laser cutter sur Linux.

Développé par **Boc@l FabLab Chemillé** — Licence GPLv3.

## Problème

xTool Studio (Electron) est instable sous Linux et ne détecte pas la P2 en WiFi.
Ce projet vise à créer un outil natif Rust + GUI (egui) stable sur Linux.

## État actuel — Phase 1 : Reverse engineering du protocole

Le protocole réseau de la P2 n'est pas encore documenté.
Ces outils permettent de le capturer et l'analyser.

## Installation

```bash
# Prérequis : Rust installé (https://rustup.rs)
cd xtool-p2
cargo build --release
sudo cp target/release/xtool-p2 /usr/local/bin/
```

## Utilisation

### Détecter la P2 sur le réseau

```bash
xtool-p2 discover
```

### Tester la connexion

```bash
xtool-p2 ping 192.168.1.42
```

### Capturer le trafic pour analyser le protocole

```bash
# Sur ce PC Linux :
sudo xtool-p2 capture -o capture.json

# En même temps, depuis un PC Windows/Mac :
# → ouvrir xTool Studio → connecter la P2 → envoyer un job simple

# Analyser la capture :
xtool-p2 analyze capture.json -o rapport.md
```

## Contribuer au reverse-engineering

Si vous capturez des paquets xTool P2, partagez vos fichiers `.json` ou `.pcap`
en ouvrant une issue sur ce dépôt. Chaque capture aide à documenter le protocole.

### Outils complémentaires

```bash
# Wireshark (capture réseau complète)
sudo apt install wireshark
sudo wireshark -i wlan0 -f "host 192.168.1.42"

# Ports à surveiller (hypothèses à confirmer)
# UDP 8765  : découverte (confirmé sur D1 Pro)
# UDP 58765 : possible port P2
# TCP 8765  : commandes
```

## Feuille de route

- [x] Phase 1 : Outils de découverte et capture réseau
- [ ] Phase 2 : Documenter le protocole P2 (besoin de captures)
- [ ] Phase 3 : Implémenter les commandes (envoi de jobs SVG/DXF)
- [ ] Phase 4 : GUI native Rust avec egui

## Ressources

- [Meerk40t](https://github.com/meerk40t/meerk40t) — logiciel open source qui supporte certaines xTool
- [xTool community](https://www.xtool.com/pages/community)
