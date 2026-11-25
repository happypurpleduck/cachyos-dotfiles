---
name: dotfiles-desktop
description: The desktop configuration in this repo — Hyprland's Lua config and per-host host.lua, the Quickshell "mocha-shell" (bar, launcher, control center, lock, greeter), wallpaper-driven Catppuccin Mocha theming via mocha-theme, PipeWire audio filters and host.json, and the greetd greeter. Use when changing keybinds, monitors, autostart, shell modules, theming, audio, or the login screen.
---

# Desktop: Hyprland + mocha-shell

## Hyprland (`common/hypr/.config/hypr/hyprland.lua`)

The config is **Lua** (`hl.monitor`, `hl.bind`, `hl.exec_cmd`, `hl.env`,
`hl.device` …; wiki.hypr.land). It is shared; at the end it loads
`~/.config/hypr/host.lua` from `hosts/<host>/home/.config/hypr/host.lua`, which
holds monitors, workspace→monitor pinning, GPU env vars, per-device input and an
optional `return { autostart = function() … end }`. Machine-specific things
go in host.lua, never in the shared file. `mocha-theme.lua` is generated
(gitignored) and pulled in with `pcall(require, "mocha-theme")`.
After editing: `hyprctl reload` (applies live; `hyprctl configerrors` to check).

## mocha-shell (`common/quickshell/.config/quickshell/`)

Quickshell (QML). `shell.qml` is the entry point and IPC surface; `core/`
(Theme tokens, Panels state, Hypr helpers), `components/`, `services/` (audio,
media, network, clipboard, …), `modules/` (bar, launcher, controlcenter, osd,
session, lock, overview, polkit, capture, idle), `greeter/`, `scripts/`. Its
README lists keybinds and IPC. Inspect live state with `qs ipc show` and
`qs ipc call <target> <fn>`; Quickshell hot-reloads QML on save, so watch for
errors with `qs log` / the shell's journal output rather than restarting.
Keybinds that open shell panels are in hyprland.lua and call `qs ipc call …`.

## Theming

`scripts/mocha-theme set <img> | random | accent <name|auto>` snaps the
wallpaper's colour to one of the 14 Mocha accents, writes
`~/.local/state/mocha-shell/theme.json`, and renders kitty, Hyprland, Hokum,
GTK, Qt, KDE, fuzzel and greeter themes. Those outputs are **generated and
gitignored** — change the templates/renderer in `mocha-theme`, not the outputs.
`scripts/first-login.py` renders them offline on a fresh install.

## Audio

`common/pipewire/.config/pipewire/`: `mocha-micnc.conf` (RNNoise mic
denoise), `mocha-autoeq.conf` + `.conf.d` (parametric EQ from `autoeq/*.txt`).
Nothing is active unless the host opts in through
`hosts/<host>/home/.config/mocha-shell/host.json` (`audio.labels`,
`audio.autoeq`, `audio.micDenoise`); `scripts/audiofx` and the control center
read it. Host-only PipeWire modules (e.g. VBAN on husain-pc) go in
`hosts/<host>/home/.config/pipewire/pipewire.conf.d/`.

## Greeter and session

greetd + cage running the Quickshell greeter (`greeter/`,
`scripts/install-greeter`, `scripts/greeter-control.py`). Changes need
`dot greeter --stage/--install` (sudo, user-run) and take effect at next login;
a broken greeter means no graphical login, so keep the rollback path
(`dot greeter --rollback TXID`) intact and mention it. Lock screen PAM lives in
`pam/`; `system/setup` handles the optional gnome-keyring PAM hooks.

## Checking your change

You can't see the screen. Validate what you can (`hyprctl configerrors`,
`qs` log output, `bash -n` on scripts, the Python tests) and tell the user what
to look at; ask for a screenshot if the result is visual.
