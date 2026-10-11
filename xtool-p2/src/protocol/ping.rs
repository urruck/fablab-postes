/// Test de connectivité avec la xTool P2.
///
/// Tente une connexion TCP sur les ports connus et mesure le temps de réponse.
/// Si le protocole P2 n'est pas encore documenté, on fait au moins un TCP connect.

use anyhow::Result;
use std::time::{Duration, Instant};
use tokio::net::TcpStream;
use tokio::time::timeout;
use tracing::info;

use super::{CONNECT_TIMEOUT_MS, P2_TCP_PORT, P2_TCP_PORT_ALT};

pub async fn run(ip: &str, count: u32) -> Result<()> {
    info!("Ping TCP vers {} ({} essais)\n", ip, count);

    for port in [P2_TCP_PORT, P2_TCP_PORT_ALT] {
        println!("Test connexion {}:{}", ip, port);
        println!("{}", "─".repeat(40));

        let mut success = 0u32;
        let mut total_ms = 0u128;

        for i in 1..=count {
            let addr = format!("{}:{}", ip, port);
            let start = Instant::now();

            match timeout(
                Duration::from_millis(CONNECT_TIMEOUT_MS),
                TcpStream::connect(&addr),
            )
            .await
            {
                Ok(Ok(_stream)) => {
                    let elapsed = start.elapsed().as_millis();
                    println!("  #{}: OK  {:.1} ms", i, elapsed);
                    success += 1;
                    total_ms += elapsed;
                }
                Ok(Err(e)) => {
                    println!("  #{}: REFUSÉ — {}", i, e);
                }
                Err(_) => {
                    println!("  #{}: TIMEOUT (>{}ms)", i, CONNECT_TIMEOUT_MS);
                }
            }

            if i < count {
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
        }

        println!();
        if success > 0 {
            println!("  Résultat : {}/{} réussi | moy. {:.1} ms",
                success, count, total_ms as f64 / success as f64);
            println!("  Port {} actif ✓", port);
        } else {
            println!("  Résultat : 0/{} — port {} inaccessible", count, port);
        }
        println!();
    }

    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("Si aucun port ne répond :");
    println!("  • La P2 est peut-être en mode AP (hotspot)");
    println!("    → connectez le PC au WiFi de la P2 directement");
    println!("  • Le port TCP est différent de 8765/8766");
    println!("    → lancez une capture pour le découvrir :");
    println!("    sudo xtool-p2 capture -o capture.json");

    Ok(())
}
