/// Récupération des informations de la xTool P2.
///
/// Tente plusieurs approches pour obtenir les infos de la machine :
///   1. HTTP sur le port 80/8080 (interface web embarquée éventuelle)
///   2. Requête UDP de découverte et lecture de la réponse
///   3. Connexion TCP sur le port xTool et envoi de la commande info connue
///
/// NOTE : le format exact des commandes P2 est à confirmer par capture réseau.

use anyhow::Result;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpStream, UdpSocket};
use tokio::time::timeout;
use tracing::{debug, warn};

use super::{CONNECT_TIMEOUT_MS, P2_TCP_PORT};

// Commandes candidates pour obtenir les infos machine.
// Ces valeurs sont des hypothèses basées sur d'autres machines xTool.
// À valider par capture Wireshark.
const INFO_COMMANDS: &[&[u8]] = &[
    b"M115\n",           // Commande Marlin/GRBL standard pour firmware info
    b"M115\r\n",
    b"{\"cmd\":\"info\"}\n",    // Format JSON possible
    b"GET_INFO\r\n",
    b"xTool:info\r\n",
];

pub async fn run(ip: &str) -> Result<()> {
    println!("Récupération des informations de la xTool P2 : {}\n", ip);

    // 1. Essai HTTP (interface web embarquée)
    println!("1. Test interface web embarquée...");
    for port in [80u16, 8080, 3000, 8888] {
        match try_http(ip, port).await {
            Ok(Some(response)) => {
                println!("   ✓ Interface web sur le port {} :", port);
                println!("   {}", &response[..response.len().min(200)]);
            }
            Ok(None) => debug!("   Port {} HTTP : pas de réponse", port),
            Err(e) => debug!("   Port {} HTTP : {}", port, e),
        }
    }

    // 2. Essai UDP de découverte
    println!("\n2. Requête UDP de découverte...");
    match try_udp_info(ip).await {
        Ok(Some(data)) => {
            println!("   ✓ Réponse UDP :");
            println!("   ASCII : {}", String::from_utf8_lossy(&data));
            println!("   HEX   : {}", hex::encode(&data));
        }
        Ok(None) => println!("   Pas de réponse UDP"),
        Err(e) => warn!("   Erreur UDP : {}", e),
    }

    // 3. Essai connexion TCP + commandes info
    println!("\n3. Connexion TCP sur le port {}...", P2_TCP_PORT);
    match try_tcp_info(ip, P2_TCP_PORT).await {
        Ok(Some(response)) => {
            println!("   ✓ Réponse TCP :");
            println!("   ASCII : {}", String::from_utf8_lossy(&response));
            println!("   HEX   : {}", hex::encode(&response));
        }
        Ok(None) => println!("   Connexion TCP refusée ou pas de réponse"),
        Err(e) => warn!("   Erreur TCP : {}", e),
    }

    println!("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("Pour aller plus loin :");
    println!("  xtool-p2 capture -i {} -o capture.json", ip);
    println!("  (ouvrez xTool Studio ailleurs pendant la capture)");

    Ok(())
}

async fn try_http(ip: &str, port: u16) -> Result<Option<String>> {
    let _url = format!("http://{}:{}/", ip, port);
    match timeout(
        Duration::from_millis(CONNECT_TIMEOUT_MS),
        TcpStream::connect(format!("{}:{}", ip, port)),
    )
    .await
    {
        Ok(Ok(mut stream)) => {
            let req = format!("GET / HTTP/1.0\r\nHost: {}\r\n\r\n", ip);
            stream.write_all(req.as_bytes()).await?;

            let mut buf = Vec::new();
            timeout(Duration::from_secs(3), stream.read_to_end(&mut buf)).await??;
            if buf.is_empty() {
                return Ok(None);
            }
            Ok(Some(String::from_utf8_lossy(&buf).to_string()))
        }
        _ => Ok(None),
    }
}

async fn try_udp_info(ip: &str) -> Result<Option<Vec<u8>>> {
    let sock = UdpSocket::bind("0.0.0.0:0").await?;
    let dest = format!("{}:8765", ip);

    for payload in [b"M99999" as &[u8], b"xTool_Find_Device", b"GET_INFO\r\n"] {
        sock.send_to(payload, &dest).await?;
        let mut buf = vec![0u8; 4096];
        match timeout(Duration::from_secs(2), sock.recv_from(&mut buf)).await {
            Ok(Ok((n, _))) => return Ok(Some(buf[..n].to_vec())),
            _ => continue,
        }
    }
    Ok(None)
}

async fn try_tcp_info(ip: &str, port: u16) -> Result<Option<Vec<u8>>> {
    let addr = format!("{}:{}", ip, port);
    match timeout(
        Duration::from_millis(CONNECT_TIMEOUT_MS),
        TcpStream::connect(&addr),
    )
    .await
    {
        Ok(Ok(mut stream)) => {
            for cmd in INFO_COMMANDS {
                stream.write_all(cmd).await?;
                let mut buf = vec![0u8; 4096];
                match timeout(Duration::from_secs(2), stream.read(&mut buf)).await {
                    Ok(Ok(n)) if n > 0 => return Ok(Some(buf[..n].to_vec())),
                    _ => continue,
                }
            }
            Ok(None)
        }
        _ => Ok(None),
    }
}
