# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Please ADD ALL Changes to the UNRELEASED SECTION and not a specific release
-->

## [Unreleased]
### Security
### Added
- fetch: added --switch-to-main flag to switch to the default branch and rebase it when not on it, skipping if there are uncommitted changes
- git/ignore-changelog: script to add CHANGELOG.md to .markdownlintignore across git repositories
- git/reset-all: script to run git reset --hard HEAD across all git repositories
- git/push-all: script to push all git repositories
- linux/dev-update: script to pull core dev repos (scripts, credfeto-global-pre-commit, cs-template, credfeto-ai-skills) and reinstall AI skills
- general/update-dotnet-tools: migrate globally-installed dotnet tools to local, uninstalling them from global and installing locally if not already present, before updating local tools
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
- Replace raw echo with output helpers in git/all-to-default-branch
- Replaced raw echo calls with die/info/success output helpers in general/wallpaper
- Replace raw echo with output helpers in general/update-dotnet-tools
- Replace raw echo with output helpers in general/stream
- Replace raw echo with output helpers in general/ssh-key-mgr
- Replace raw echo with output helpers in general/install-latest-dotnet
- Replaced raw echo with output helpers in general/install-dotnet-tools
- Replace raw echo with output helpers in general/convert-video
- Replace raw echo with output helpers in development/sln-migrate
- Replace raw echo with output helpers in development/restore-all
- Replace raw echo with output helpers in development/buildtest
- Replace raw echo with output helpers in development/buildnugetconfig
- Replace raw echo with output helpers in development/buildcheck
- Replace raw echo with output helpers in db/install-mssql
- Replace raw echo with output helpers in db/dropmssqldb
- Replace raw echo with output helpers in db/dbenv
- Replace raw echo with output helpers in db/dbappsettings
- Replace raw echo with output helpers in db/createmssqldb
- Replace raw echo with standard output helpers (die/info/success) in db/create-deploy-script
- git/fetch: Unset core.hookspath for each repo during fetch so that globally-configured hook paths do not persist on individual repos
- check: use mapfile array for file collection to handle filenames containing spaces correctly
- check: guard against empty file list before checking — prevents false-positive success when no scripts are found
- git/ignore-changelog: skip push hooks when pushing to target repositories
- git/fetch and git/switchtomain now warn and skip a repo on error instead of aborting the whole run, so remaining repos still get processed.
- development/buildtest now runs unit tests first, always excluding benchmark test projects, then runs any benchmark projects found individually without the --long-running/--parallel-algorithm flags, since some benchmark projects' test host rejects them as invalid arguments (exit code 5, zero tests ran) instead of running
- development/buildtest: fixed the --no-benchmarks/--no-integration flag typos and the broken TEST_INTEGRATION filter assignment so --no-integration actually excludes integration tests
### Changed
- Replace raw echo with standard output helpers (die/info/success) in github/cancel-workflows
- Replace raw echo with standard output helpers (die/info/success) in git/update-repos-personal
- Replace raw echo with output helpers (die, info, success) in git/missing-release-branches
- git/make-preview: replaced raw echo with die/info/success output helpers
- Replaced raw echo with output helpers (die/info/success) in git/clean-all
- check: replaced raw echo-based output with standard die, info, and success helpers
- git fetch: skip resetting core.hookspath for whitelisted repositories (e.g. funfair-treasury-reporting)
- GEOIP - Updated GEOIP DB from MaxMind (2026-07-18)
### Deprecated
### Removed
- db/sqlcompare script deleted — no longer in use
### Deployment Changes
<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created