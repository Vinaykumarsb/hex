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

#[cfg(test)]
mod tests {
    #[test]
    fn an_unstamped_build_is_hex() {
        if option_env!("HEX_EDITION_NAME").is_none() {
            assert_eq!(super::name(), None);
            assert_eq!(super::app_name(), "Hex");
        }
    }
}
