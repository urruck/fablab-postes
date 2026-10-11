/// Capture et analyse du trafic réseau xTool P2.
///
/// Écoute sur tous les ports connus et enregistre chaque paquet UDP/TCP
/// dans un fichier JSON pour permettre le reverse-engineering du protocole.
///
/// Usage recommandé :
///   1. Connecter la P2 sur le même réseau que ce PC et un PC Windows/Mac
///   2. Lancer : sudo xtool-p2 capture -o capture.json
///   3. Depuis le PC Windows/Mac : ouvrir xTool Studio et se connecter à la P2
///   4. Effectuer des actions : découverte, gravure simple, etc.
///   5. Arrêter la capture (Ctrl+C) et analyser avec : xtool-p2 analyze capture.json

use anyhow::Result;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use tokio::fs::File;
use tokio::io::AsyncWriteExt;
use tokio::net::UdpSocket;
use tokio::time::Duration;
use tracing::{debug, info, warn};

const CAPTURE_PORTS: &[u16] = &[
    8765, 8766, 8767, 8899,
    58765, 58766,
    5555, 6000, 6001,
    80, 8080, 8443,
    3000, 4000, 9000,
];

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Packet {
    pub timestamp: String,
    pub direction: String,   // "received" ou "sent"
    pub protocol: String,    // "UDP" ou "TCP"
    pub src_ip: String,
    pub src_port: u16,
    pub dst_port: u16,
    pub size: usize,
    pub hex: String,
    pub ascii: String,
    pub is_printable: bool,
}

impl Packet {
    fn from_udp(addr: SocketAddr, dst_port: u16, data: &[u8]) -> Self {
        let ascii: String = data.iter().map(|&b| {
            if b.is_ascii_graphic() || b == b' ' { b as char } else { '.' }
        }).collect();
        let is_printable = data.iter().filter(|&&b| b.is_ascii_graphic()).count() > data.len() / 2;
        Self {
            timestamp: Utc::now().to_rfc3339(),
            direction: "received".to_string(),
            protocol: "UDP".to_string(),
            src_ip: addr.ip().to_string(),
            src_port: addr.port(),
            dst_port,
            size: data.len(),
            hex: hex::encode(data),
            ascii,
            is_printable,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CaptureSession {
    pub started_at: String,
    pub filter_ip: Option<String>,
    pub packets: Vec<Packet>,
    pub stats: CaptureStats,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct CaptureStats {
    pub total_packets: usize,
    pub unique_sources: Vec<String>,
    pub packets_per_port: HashMap<u16, usize>,
}

pub async fn run(output: String, filter_ip: Option<String>, timeout_secs: u64) -> Result<()> {
    info!("Capture réseau xTool P2 démarrée");
    info!("Fichier de sortie : {}", output);
    if let Some(ref ip) = filter_ip {
        info!("Filtre IP : {}", ip);
    }
    info!("Durée : {} secondes (0 = infini)", timeout_secs);
    info!("");
    info!("Ports surveillés : {:?}", CAPTURE_PORTS);
    info!("");
    info!("INSTRUCTIONS :");
    info!("  Depuis un PC Windows/Mac sur le même réseau :");
    info!("    1. Ouvrez xTool Studio");
    info!("    2. Connectez-vous à la P2 (WiFi)");
    info!("    3. Effectuez quelques actions (découverte, envoi de job)");
    info!("    4. Appuyez Ctrl+C ici pour arrêter la capture");
    info!("");
    warn!("Si aucun paquet n'est reçu, vérifiez que le pare-feu est ouvert :");
    warn!("  sudo ufw allow from any to any port 8765 proto udp");
    info!("");

    let session = Arc::new(tokio::sync::Mutex::new(CaptureSession {
        started_at: Utc::now().to_rfc3339(),
        filter_ip: filter_ip.clone(),
        packets: Vec::new(),
        stats: CaptureStats::default(),
    }));

    let mut handles = Vec::new();

    for &port in CAPTURE_PORTS {
        let addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), port);
        match UdpSocket::bind(addr).await {
            Ok(sock) => {
                let session_clone = Arc::clone(&session);
                let filter = filter_ip.clone();
                handles.push(tokio::spawn(async move {
                    capture_port(sock, port, session_clone, filter).await
                }));
                debug!("Écoute UDP sur le port {}", port);
            }
            Err(e) => {
                debug!("Port {} non disponible : {}", port, e);
            }
        }
    }

    info!("Capture en cours... (Ctrl+C pour arrêter)\n");

    // Attendre le timeout ou Ctrl+C
    let wait = if timeout_secs > 0 {
        tokio::time::sleep(Duration::from_secs(timeout_secs))
    } else {
        tokio::time::sleep(Duration::from_secs(u64::MAX))
    };

    tokio::select! {
        _ = wait => {
            info!("Durée de capture écoulée.");
        }
        _ = tokio::signal::ctrl_c() => {
            info!("Capture interrompue par l'utilisateur.");
        }
    }

    // Arrêter les tâches
    for h in handles {
        h.abort();
    }

    // Sauvegarder la session
    let session_data = session.lock().await;
    let json = serde_json::to_string_pretty(&*session_data)?;
    let mut file = File::create(&output).await?;
    file.write_all(json.as_bytes()).await?;

    println!();
    println!("╔══════════════════════════════════════════════════════╗");
    println!("║  Capture terminée                                    ║");
    println!("╚══════════════════════════════════════════════════════╝");
    println!("  Paquets capturés : {}", session_data.stats.total_packets);
    println!("  Sources uniques  : {:?}", session_data.stats.unique_sources);
    println!("  Fichier          : {}", output);
    println!();
    println!("  Pour analyser le protocole :");
    println!("    xtool-p2 analyze {} -o rapport.md", output);

    Ok(())
}

use std::sync::Arc;

async fn capture_port(
    sock: UdpSocket,
    port: u16,
    session: Arc<tokio::sync::Mutex<CaptureSession>>,
    filter_ip: Option<String>,
) -> Result<()> {
    let mut buf = vec![0u8; 65535];
    loop {
        match sock.recv_from(&mut buf).await {
            Ok((n, addr)) => {
                let data = &buf[..n];

                // Appliquer le filtre IP
                if let Some(ref fip) = filter_ip {
                    if addr.ip().to_string() != *fip {
                        continue;
                    }
                }

                let pkt = Packet::from_udp(addr, port, data);

                info!(
                    "UDP port {:5} ← {} ({} octets) | {}",
                    port,
                    addr,
                    n,
                    if pkt.is_printable { &pkt.ascii } else { &pkt.hex }
                );

                let mut s = session.lock().await;
                s.stats.total_packets += 1;
                let src = addr.ip().to_string();
                if !s.stats.unique_sources.contains(&src) {
                    s.stats.unique_sources.push(src);
                }
                *s.stats.packets_per_port.entry(port).or_insert(0) += 1;
                s.packets.push(pkt);
            }
            Err(e) => {
                debug!("Port {} : erreur : {}", port, e);
                break;
            }
        }
    }
    Ok(())
}

pub async fn analyze(input: String, output: String) -> Result<()> {
    info!("Analyse du fichier de capture : {}", input);

    let content = tokio::fs::read_to_string(&input).await?;
    let session: CaptureSession = serde_json::from_str(&content)?;

    info!("{} paquets à analyser", session.packets.len());

    let mut report = String::new();
    report.push_str("# Rapport d'analyse du protocole xTool P2\n\n");
    report.push_str(&format!("**Capture du** : {}\n\n", session.started_at));
    report.push_str(&format!("**Total paquets** : {}\n\n", session.stats.total_packets));

    report.push_str("## Sources détectées\n\n");
    for src in &session.stats.unique_sources {
        report.push_str(&format!("- `{}`\n", src));
    }

    report.push_str("\n## Activité par port\n\n");
    report.push_str("| Port | Paquets | Usage probable |\n");
    report.push_str("|------|---------|----------------|\n");
    let mut ports: Vec<_> = session.stats.packets_per_port.iter().collect();
    ports.sort_by_key(|&(p, _)| p);
    for (port, count) in &ports {
        let usage = guess_port_usage(**port);
        report.push_str(&format!("| {} | {} | {} |\n", port, count, usage));
    }

    report.push_str("\n## Paquets (échantillon)\n\n");
    for (i, pkt) in session.packets.iter().take(50).enumerate() {
        report.push_str(&format!(
            "### Paquet #{} — {} | {} → port {}\n\n",
            i + 1, pkt.timestamp, pkt.src_ip, pkt.dst_port
        ));
        if pkt.is_printable {
            report.push_str(&format!("**ASCII** : `{}`\n\n", pkt.ascii));
        }
        report.push_str(&format!("**HEX** : `{}`\n\n", pkt.hex));
    }

    report.push_str("\n## Analyse des patterns\n\n");
    let analysis = analyze_patterns(&session.packets);
    report.push_str(&analysis);

    report.push_str("\n## Prochaines étapes\n\n");
    report.push_str("1. Identifier les paquets de découverte (broadcast UDP)\n");
    report.push_str("2. Identifier le handshake de connexion TCP\n");
    report.push_str("3. Documenter le format des commandes (envoi de job)\n");
    report.push_str("4. Implémenter le protocole dans `src/protocol/`\n");

    tokio::fs::write(&output, report).await?;
    info!("Rapport généré : {}", output);

    Ok(())
}

fn guess_port_usage(port: u16) -> &'static str {
    match port {
        8765 => "Découverte/commandes xTool (D1 Pro confirmé)",
        8766 => "Possible variante xTool",
        8899 => "Possible données/streaming",
        58765 => "Possible découverte P2 (à confirmer)",
        80 | 8080 => "Interface web embarquée ?",
        5555 => "ADB / debug Android (Makeblock)",
        _ => "Inconnu",
    }
}

fn analyze_patterns(packets: &[Packet]) -> String {
    let mut out = String::new();

    // Chercher les patterns récurrents dans les hex
    let mut hex_prefixes: HashMap<String, usize> = HashMap::new();
    for pkt in packets {
        if pkt.hex.len() >= 8 {
            let prefix = pkt.hex[..8].to_string();
            *hex_prefixes.entry(prefix).or_insert(0) += 1;
        }
    }

    if !hex_prefixes.is_empty() {
        out.push_str("### Préfixes hex récurrents (début de paquet)\n\n");
        let mut prefixes: Vec<_> = hex_prefixes.iter().filter(|&(_, c)| *c > 1).collect();
        prefixes.sort_by_key(|&(_, c)| std::cmp::Reverse(*c));
        for (prefix, count) in prefixes.iter().take(10) {
            out.push_str(&format!("- `{}...` × {} paquets\n", prefix, count));
        }
        out.push('\n');
    }

    // Chercher des chaînes ASCII reconnaissables
    let keywords = ["xTool", "P2", "laser", "status", "ok", "error", "ready",
                    "start", "stop", "home", "move", "power", "speed"];
    let mut found_keywords = Vec::new();
    for pkt in packets {
        let ascii_lower = pkt.ascii.to_lowercase();
        for kw in &keywords {
            if ascii_lower.contains(&kw.to_lowercase()) && !found_keywords.contains(kw) {
                found_keywords.push(kw);
            }
        }
    }

    if !found_keywords.is_empty() {
        out.push_str("### Mots-clés détectés dans les paquets\n\n");
        for kw in &found_keywords {
            out.push_str(&format!("- `{}`\n", kw));
        }
        out.push('\n');
    }

    if out.is_empty() {
        out.push_str("*Aucun pattern significatif détecté — plus de paquets nécessaires.*\n");
        out.push_str("\nCapturez une session complète : démarrage xTool Studio → connexion P2 → envoi d'un job simple.\n");
    }

    out
}

