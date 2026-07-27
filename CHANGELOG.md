# Changelog

## Unreleased - 2026-07-28

### Fixed

- Wait for a fresh staged snapshot when an active staging marker was observed.
- Preserve a recent valid multi-item stage when a late Explorer callback reports an empty or mismatched single selection.
- Probe Desktop selection even when another Explorer window yielded a stale fallback selection.
- Avoid expensive top-level directory enumeration unless a large-selection token can be used.

### Changed

- Added a repository line-ending policy for scripts, documentation, configuration, and Windows integration files.
- Added a regression check for engine syntax, safety markers, and the MoveTune-only runtime policy.
