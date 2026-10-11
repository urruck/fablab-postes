mod discover;
mod protocol;
mod capture;

use anyhow::Result;
use clap::{Parser, Subcommand};
use tracing_subscriber::EnvFilter;

#[derive(Parser)]
#[command(
    name = "xtool-p2",
    about = "Pilotage open-source de la xTool P2 sous Linux",
    version,
    long_about = "Outil CLI pour détecter, analyser et piloter la xTool P2 laser.\n\
                  Développé par Boc@l FabLab Chemillé — licence GPLv3."
)]
struct Cli {
    #[arg(short, long, global = true)]
    verbose: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Détecter la xTool P2 sur le réseau local (UDP broadcast)
    Discover {
        #[arg(short, long, default_value = "10")]
        timeout: u64,
        #[arg(short, long)]
        interface: Option<String>,
    },

    /// Capturer le trafic réseau xTool P2 (reverse-engineering du protocole)
    Capture {
        #[arg(short, long, default_value = "xtool-capture.json")]
        output: String,
        #[arg(short, long)]
        ip: Option<String>,
        #[arg(short, long, default_value = "60")]
        timeout: u64,
    },

    /// Tester la connexion avec la machine
    Ping {
        ip: String,
        #[arg(short, long, default_value = "4")]
        count: u32,
    },

    /// Afficher les informations de la machine
    Info {
        ip: String,
    },

    /// Analyser un fichier de capture JSON et générer un rapport de protocole
    Analyze {
        input: String,
        #[arg(short, long, default_value = "protocole-p2.md")]
        output: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    let filter = if cli.verbose { "debug" } else { "info" };
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::new(filter))
        .with_target(false)
        .init();

    match cli.command {
        Commands::Discover { timeout, interface } => {
            discover::run(timeout, interface).await?;
        }
        Commands::Capture { output, ip, timeout } => {
            capture::run(output, ip, timeout).await?;
        }
        Commands::Ping { ip, count } => {
            protocol::ping::run(&ip, count).await?;
        }
        Commands::Info { ip } => {
            protocol::info::run(&ip).await?;
        }
        Commands::Analyze { input, output } => {
            capture::analyze(input, output).await?;
        }
    }

    Ok(())
}
