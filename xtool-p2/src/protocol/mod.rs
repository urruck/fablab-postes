pub mod ping;
pub mod info;

/// Ports TCP connus pour la communication avec la P2.
/// À confirmer par capture Wireshark.
pub const P2_TCP_PORT: u16 = 8765;
pub const P2_TCP_PORT_ALT: u16 = 8766;

/// Timeout de connexion en millisecondes
pub const CONNECT_TIMEOUT_MS: u64 = 5000;
