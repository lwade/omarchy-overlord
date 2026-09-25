# Overlord

Omarchy shell plugin `io.github.lwade.overlord`. Quattro contract: `manifest.json` at the repo root. Kinds are `service` and `bar-widget`. The board is a `KeyboardPanel` anchored to the bar icon, not a centered overlay.

- Do not start a second Quickshell process. Do not use `omarchy plugin clone`.
- Do not put symlinks in the plugin tree. `scripts/install-dev` copies into `~/.config/omarchy/plugins/io.github.lwade.overlord`.
- Board file: `$XDG_DATA_HOME/omarchy-overlord/overlord.json` (default `~/.local/share/omarchy-overlord/overlord.json`), unless `notesDir` is set on the bar widget in `shell.json`. The file name stays `overlord.json`. A leftover `board.json` in that folder is read once and written out as `overlord.json`. Version 1. Quadrant is derived from `urgent` and `important`, never stored. `simple`, `confirmDelete`, and `stats` are persisted. `confirmDelete` defaults on. `stats.do` and `stats.schedule` count ticks, not filings. A Do tick is done. A Schedule tick is scheduled. Filing into those columns does not count. `stats.delegate` counts notes filed into Delegate. `stats.eliminate` counts deletes, drops, and 24-hour flushes. Missing stats load as zeros. Delegate cards carry `delegatedAt` and are removed after 24 hours. Delete means remove the card. A tick removes the card and does not ask.
- Third-party `shell` is a facade. The bar widget toggles its own panel. Read state with `bar.shell.serviceFor(moduleName)`.
- `keepLoaded` is true. Service code changes need `omarchy restart shell`.
- Validate with `omarchy plugin validate .` and `qmllint -I "$OMARCHY_PATH/shell"`.
