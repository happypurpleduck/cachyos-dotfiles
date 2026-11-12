# Mocha shell

A Quickshell desktop shell for Hyprland: clean Catppuccin Mocha, with the accent
picked from the current wallpaper and applied everywhere.

## How the theming works

`scripts/mocha-theme` finds the wallpaper's dominant colour, snaps it to the
nearest of the 14 Mocha accents and writes `~/.local/state/mocha-shell/theme.json`.
Then it re-renders:

| Target | File | Live? |
|---|---|---|
| Quickshell | reads `theme.json` | yes |
| Hyprland borders | `~/.config/hypr/mocha-theme.lua` | yes (Lua dispatch) |
| kitty | `~/.config/kitty/mocha-theme.conf` | yes (SIGUSR1) |
| Hokum | `~/.config/hokum/themes/mocha.kdl` | yes (hot reload) |
| GTK 3/4 | `~/.config/gtk-{3,4}.0/gtk.css` | on app restart |
| Qt | `~/.config/qt{5,6}ct/colors/mocha.conf` | on app restart |
| KDE apps (Dolphin, Kate, …) | `~/.config/kdeglobals`, `~/.local/share/color-schemes/CatppuccinMocha.colors`, `[UiSettings]` in each app's rc | on app restart |
| fuzzel (fallback) | `~/.config/fuzzel/fuzzel.ini` | next launch |
| greeter | `/etc/greetd/mocha-greeter/theme.json` | next login |

```
mocha-theme set <image>      # wallpaper + auto accent
mocha-theme random           # random wallpaper from ~/Pictures/Wallpapers/catppuccin-mocha
mocha-theme accent mauve     # force an accent ("auto" to follow the wallpaper again)
```

## Keys

| Keys | Action |
|---|---|
| `Super+Return` / `Super+R` | launcher (`>` clipboard · `:` emoji · `=` calc · `@` wallpapers · `/` actions) |
| `Super+Shift+V` / `Super+.` / `Super+W` / `Super+/` | launcher in clipboard / emoji / wallpaper / actions mode |
| `Super+Shift+W` | random wallpaper |
| `Super+A` | control center |
| `Super+Tab` | workspace overview (drag windows between workspaces) |
| `Alt+Tab` | window switcher |
| `Super+Esc` | power menu (Lock preselected: `Super+Esc`, `Enter` locks) |
| `Super+\` / `Super+Q` | terminal |
| `Super+H J K L` / arrows | focus window left / down / up / right (`+Shift` moves it) |
| `Super+S` | toggle split direction |
| `Print` | screenshot: click a window, drag a region, or click the desktop for the whole screen |
| `Shift+Print` / `Alt+Print` | screenshot screen / focused window |
| `Super+Print` | capture menu (screenshots, recording, colour picker) |
| `Super+Shift+R` | record a region (press again to stop) |
| `Super+Shift+C` | colour picker |
| `Super+F` / `Super+Shift+F` | maximise / fullscreen |

## IPC

```
qs ipc show                      # list every target and function
qs ipc call theme accent peach
qs ipc call toggles gamemode
```

## Layout

```
shell.qml            entry point + IPC
core/                Theme (tokens), Panels (open state), Hypr (dispatch helpers)
components/          shared widgets
services/            audio, media, stats, weather, clipboard, apps, network, …
modules/             bar, launcher, controlcenter, osd, session, lock, overview,
                     polkit, capture, idle
greeter/             greetd login screen (installed by scripts/install-greeter)
scripts/             mocha-theme, capture, audiofx, bt-agent, install-greeter
pam/                 PAM config for the lock screen
```

Idle: lock after 5 min, monitors off after 7, never suspends (see `modules/idle/Idle.qml`).
Fullscreen windows (videos, games) and "Keep awake" in the control center hold both off.
