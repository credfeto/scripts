# Changelog
All notable changes to this project will be documented in this file.

<!--
Please ADD ALL Changes to the UNRELEASED SECTION and not a specific release
-->

## [Unreleased]
### Security
### Added
- fetch: added --switch-to-main flag to switch to the default branch and rebase it when not on it, skipping if there are uncommitted changes
### Fixed
- Shell scripts were cleaned up to pass pre-commit checks, and git/fetch now uses consistent info/success output.
- Replace raw echo output with standard die/success/info helpers in network/wg-create
- Replace raw echo with output helpers in linux/install-fp
### Changed
- GEOIP - Updated GEOIP DB from MaxMind (2026-06-03)
- Replace raw echo with standard output helpers (die/info/success) in github/cancel-workflows
- Replace raw echo with standard output helpers (die/info/success) in git/update-repos-personal
### Deprecated
### Removed
### Deployment Changes
<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created