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
- Replace raw echo with output helpers in git/update-preview
- Replace raw echo with standard output helpers in git/update-dotnet-sdk
- Replace raw echo with standard output helpers in git/switchtomain
- Replace raw echo with output helpers in git/optimise-git
- Replace raw echo with output helpers in git/mkmissing-release
- Replace raw echo with output helpers in git/init-preview
- Replace raw echo with output helpers in git/clone-repos
- Inline enable-auto-merge and auto-approve scripts in Pull Request workflow to fix pull_request_target local action resolution failure
### Changed
- Replace raw echo with standard output helpers (die/info/success) in github/cancel-workflows
- Replace raw echo with standard output helpers (die/info/success) in git/update-repos-personal
- Replace raw echo with output helpers (die, info, success) in git/missing-release-branches
- git/make-preview: replaced raw echo with die/info/success output helpers
- GEOIP - Updated GEOIP DB from MaxMind (2026-06-10)
### Deprecated
### Removed
### Deployment Changes
<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created