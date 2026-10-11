/// Découverte réseau de la xTool P2 via UDP broadcast.
///
/// La xTool P2 émet des broadcasts UDP sur le réseau local pour s'annoncer.
/// On écoute sur plusieurs ports connus (et on tente aussi un broadcast actif).
///
/// Ports testés (à confirmer par capture Wireshark) :
///   - 8765  : port principal xTool Studio (observé sur D1 Pro)
///   - 8080  : port alternatif observé
///   - 58765 : port de découverte P2 (à confirmer)

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use tokio::net::UdpSocket;
use tokio::time::{timeout, Duration};
use tracing::{debug, info, warn};

// Ports UDP sur lesquels la P2 est susceptible de répondre.
// À affiner après capture Wireshark.
const DISCOVERY_PORTS: &[u16] = &[8765, 8766, 58765, 8899, 5555, 6000];

// Payload du broadcast de découverte envoyé par xTool Studio.
// Valeur observée sur D1 Pro — à confirmer pour la P2 par capture réseau.
const DISCOVERY_PAYLOAD_D1: &[u8] = b"M99999";

// Payload alternatif observé dans certaines versions
const DISCOVERY_PAYLOAD_ALT: &[u8] = b"xTool_Find_Device";

#[derive(Debug, Serialize, Deserialize)]
pub struct DiscoveredDevice {
    pub ip: String,
    pub port: u16,
    pub raw_response: String,
    pub model: Option<String>,
    pub firmware: Option<String>,
    pub serial: Option<String>,
}

impl DiscoveredDevice {
    fn from_response(addr: SocketAddr, data: &[u8]) -> Self {
        let raw = String::from_utf8_lossy(data).to_string();
        let (model, firmware, serial) = parse_response(&raw);
        Self {
            ip: addr.ip().to_string(),
            port: addr.port(),
            raw_response: raw,
            model,
            firmware,
            serial,
        }
    }
}

/// Tente de parser une réponse de découverte xTool.
/// Format observé sur D1 Pro : "xTool D1 Pro,FW:1.2.3,SN:XXXXXXXX"
/// Format P2 : inconnu — à documenter via capture Wireshark.
fn parse_response(raw: &str) -> (Option<String>, Option<String>, Option<String>) {
    let mut model = None;
    let mut firmware = None;
    let mut serial = None;

    // Essai format CSV simple
    let parts: Vec<&str> = raw.split(',').collect();
    if !parts.is_empty() {
        let first = parts[0].trim();
        if first.contains("xTool") || first.contains("xtool") || first.contains("P2") {
            model = Some(first.to_string());
        }
    }
    for part in &parts {
        let p = part.trim();
        if let Some(fw) = p.strip_prefix("FW:").or_else(|| p.strip_prefix("fw:")) {
            firmware = Some(fw.to_string());
        }
        if let Some(sn) = p.strip_prefix("SN:").or_else(|| p.strip_prefix("sn:")) {
            serial = Some(sn.to_string());
        }
    }

    // Essai format JSON (certaines machines répondent en JSON)
    if model.is_none() {
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(raw) {
            model = v.get("model").or_else(|| v.get("deviceName"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
            firmware = v.get("firmware").or_else(|| v.get("fw"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
            serial = v.get("sn").or_else(|| v.get("serial"))
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
        }
    }

    (model, firmware, serial)
}

pub async fn run(timeout_secs: u64, _interface: Option<String>) -> Result<()> {
    info!("Recherche de la xTool P2 sur le réseau local...");
    info!("Écoute pendant {} secondes", timeout_secs);
    info!("");
    info!("Ports scannés : {:?}", DISCOVERY_PORTS);
    info!("");

    let mut devices: Vec<DiscoveredDevice> = Vec::new();

    // Lance l'écoute et le broadcast en parallèle
    let found = tokio::time::timeout(
        Duration::from_secs(timeout_secs),
        listen_and_broadcast(),
    )
    .await;

    match found {
        Ok(Ok(mut devs)) => {
            devices.append(&mut devs);
        }
        Ok(Err(e)) => warn!("Erreur lors de la découverte : {}", e),
        Err(_) => info!("Délai d'attente écoulé."),
    }

    println!();
    if devices.is_empty() {
        println!("╔══════════════════════════════════════════════════════╗");
        println!("║  Aucune xTool P2 détectée sur le réseau.             ║");
        println!("╠══════════════════════════════════════════════════════╣");
        println!("║  Vérifiez que :                                      ║");
        println!("║  1. La P2 est allumée et connectée au même WiFi      ║");
        println!("║  2. Le pare-feu Linux ne bloque pas les ports UDP    ║");
        println!("║     sudo ufw allow 8765/udp                          ║");
        println!("║  3. La P2 et ce PC sont sur le même sous-réseau      ║");
        println!("╠══════════════════════════════════════════════════════╣");
        println!("║  Pour analyser le protocole réseau :                 ║");
        println!("║    sudo xtool-p2 capture -o capture.json             ║");
        println!("║  (lancez xTool Studio depuis un autre PC en même    ║");
        println!("║   temps pour capturer les paquets de découverte)     ║");
        println!("╚══════════════════════════════════════════════════════╝");
    } else {
        println!("╔══════════════════════════════════════════════════════╗");
        println!("║  xTool P2 détectée !                                 ║");
        println!("╚══════════════════════════════════════════════════════╝");
        for dev in &devices {
            println!();
            println!("  IP      : {}", dev.ip);
            println!("  Port    : {}", dev.port);
            if let Some(ref m) = dev.model {
                println!("  Modèle  : {}", m);
            }
            if let Some(ref fw) = dev.firmware {
                println!("  Firmware: {}", fw);
            }
            if let Some(ref sn) = dev.serial {
                println!("  Série   : {}", sn);
            }
            println!("  Réponse brute : {:?}", dev.raw_response);
            println!();
            println!("  Prochaine étape :");
            println!("    xtool-p2 info {}", dev.ip);
            println!("    xtool-p2 ping {}", dev.ip);
        }

        // Sauvegarder les devices trouvés
        let json = serde_json::to_string_pretty(&devices)?;
        std::fs::write("xtool-devices.json", &json)?;
        println!();
        println!("  Résultats sauvegardés dans xtool-devices.json");
    }

    Ok(())
}

async fn listen_and_broadcast() -> Result<Vec<DiscoveredDevice>> {
    let mut devices = Vec::new();
    let mut tasks = Vec::new();

    // Écoute sur chaque port potentiel
    for &port in DISCOVERY_PORTS {
        let addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), port);
        match UdpSocket::bind(addr).await {
            Ok(sock) => {
                debug!("Écoute UDP sur le port {}", port);
                tasks.push(tokio::spawn(listen_port(sock, port)));
            }
            Err(e) => {
                debug!("Impossible d'écouter le port {} : {}", port, e);
            }
        }
    }

    // Envoi d'un broadcast de découverte actif
    tokio::spawn(send_discovery_broadcast());

    // Attendre les réponses (5 secondes par port)
    for task in tasks {
        if let Ok(Ok(Ok(Some(dev)))) = timeout(Duration::from_secs(5), task).await {
            info!("Appareil détecté : {}:{}", dev.ip, dev.port);
            devices.push(dev);
        }
    }

    Ok(devices)
}

async fn listen_port(sock: UdpSocket, port: u16) -> Result<Option<DiscoveredDevice>> {
    let mut buf = vec![0u8; 4096];
    match sock.recv_from(&mut buf).await {
        Ok((n, addr)) => {
            let data = &buf[..n];
            debug!("Port {} : reçu {} octets depuis {}", port, n, addr);
            debug!("  hex : {}", hex::encode(data));
            debug!("  utf8: {}", String::from_utf8_lossy(data));
            Ok(Some(DiscoveredDevice::from_response(addr, data)))
        }
        Err(e) => {
            debug!("Port {} : erreur de réception : {}", port, e);
            Ok(None)
        }
    }
}

async fn send_discovery_broadcast() -> Result<()> {
    tokio::time::sleep(Duration::from_millis(500)).await;

    let sock = UdpSocket::bind("0.0.0.0:0").await?;
    sock.set_broadcast(true)?;
    let _broadcast = SocketAddr::new(IpAddr::V4(Ipv4Addr::BROADCAST), 0);

    for &port in DISCOVERY_PORTS {
        let dest = SocketAddr::new(IpAddr::V4(Ipv4Addr::BROADCAST), port);
        for payload in [DISCOVERY_PAYLOAD_D1, DISCOVERY_PAYLOAD_ALT] {
            match sock.send_to(payload, dest).await {
                Ok(_) => debug!("Broadcast envoyé → port {} : {:?}", port, String::from_utf8_lossy(payload)),
                Err(e) => debug!("Erreur broadcast port {} : {}", port, e),
            }
        }
    }

    // Broadcast sur 255.255.255.255 et sur .255 du sous-réseau local
    info!("Broadcasts de découverte envoyés sur tous les ports connus.");
    Ok(())
}
