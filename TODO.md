# TODO

- [ ] Search Results support (safe path): detect `search-ms` / virtual selection source and route to dedicated flow, keeping normal folder/Desktop flow unchanged.
- [ ] Search Results mixed-parent mode: if enabled, group staged items by parent path and execute one transfer per parent group.
- [ ] Add guardrail: if Search Results selection cannot be resolved to real filesystem paths, fail safely with clear message (no fallback to partial/anchor-only copy).
