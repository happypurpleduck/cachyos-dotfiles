# HOSTNAME

What's specific to this machine. Linked on top of `common/` by `dot link`.

| File | What |
|---|---|
| `home/.config/hypr/host.lua` | monitors, workspace→monitor rules, GPU env vars, autostart apps |
| `home/.config/mocha-shell/host.json` | audio device names, AutoEq target, mic for noise suppression |
| `packages.txt` / `aur.txt` | packages beyond `packages/common.txt` (`dot packages` snapshots them) |
| `setup` | optional script run at the end of `dot install` |

Add more machine-only files with `dot add --host <file>`.

## Notes

- 
