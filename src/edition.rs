//! The office edition this build is, stamped at build time by
//! `HEX_EDITION_NAME` (edition/README.md). Unset, the build is upstream Hex
//! unchanged: every caller falls back to Hex's own name and behaviour, so the
//! goldens and tests never see an edition.
//!
//! An edition is handed out by its organization rather than updated from
//! Anomaly's release service, so its updater reads "Managed by your
//! organization" and never checks.

/// The edition's product name, such as "Nexus Voice", or `None` for Hex.
pub fn name() -> Option<&'static str> {
    option_env!("HEX_EDITION_NAME").filter(|name| !name.trim().is_empty())
}

/// The name windows, trays, and menus show: the edition's, else "Hex".
pub fn app_name() -> &'static str {
    name().unwrap_or("Hex")
}

/// The machine-wide folder an administrator fills with speech models, for
/// example through Intune (edition/intune/README.md), or `None` for Hex.
/// Nexus Voice reads a model there in place, read-only, and checks it against
/// its pinned SHA-256 once before first use, so people never download one.
///
/// Windows `%ProgramData%\Nexus Voice\models`, macOS
/// `/Library/Application Support/Nexus Voice/models`, Linux
/// `/opt/nexus-voice/models`; a build may name another with
/// `HEX_EDITION_MODELS_DIR`.
pub fn managed_models_dir() -> Option<std::path::PathBuf> {
    let name = name()?;
    if let Some(dir) = option_env!("HEX_EDITION_MODELS_DIR").filter(|dir| !dir.is_empty()) {
        return Some(dir.into());
    }
    if cfg!(target_os = "windows") {
        let data = std::env::var_os("ProgramData").unwrap_or_else(|| r"C:\ProgramData".into());
        Some(std::path::PathBuf::from(data).join(name).join("models"))
    } else if cfg!(target_os = "macos") {
        Some(std::path::Path::new("/Library/Application Support").join(name).join("models"))
    } else {
        let folder = name.to_lowercase().replace(' ', "-");
        Some(std::path::Path::new("/opt").join(folder).join("models"))
    }
}

/// The administrator's copy of `filename` when it is there at its pinned
/// size; a partial or wrong-size copy is ignored.
pub fn managed_model(filename: &str, bytes: u64) -> Option<std::path::PathBuf> {
    let path = managed_models_dir()?.join(filename);
    std::fs::metadata(&path)
        .is_ok_and(|metadata| metadata.is_file() && metadata.len() == bytes)
        .then_some(path)
}

/// Where an edition downloads models it doesn't find in the managed folder:
/// the organization's mirror (`HEX_EDITION_MODEL_MIRROR`, such as an Azure
/// Blob container URL) in place of Hugging Face. Files keep their names and
/// pinned checksums, so a mirror can serve only the exact pinned bytes.
pub fn model_mirror() -> Option<&'static str> {
    name()?;
    option_env!("HEX_EDITION_MODEL_MIRROR")
        .map(|url| url.trim_end_matches('/'))
        .filter(|url| url.starts_with("https://"))
}

#[cfg(test)]
mod tests {
    #[test]
    fn an_unstamped_build_is_hex() {
        if option_env!("HEX_EDITION_NAME").is_none() {
            assert_eq!(super::name(), None);
            assert_eq!(super::app_name(), "Hex");
            assert_eq!(super::managed_models_dir(), None);
            assert_eq!(super::managed_model("model.gguf", 1), None);
            assert_eq!(super::model_mirror(), None);
        }
    }
}
