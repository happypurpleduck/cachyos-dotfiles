pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Design tokens for the whole shell.
// Surfaces are fixed Catppuccin Mocha; the accent follows the wallpaper
// (written by scripts/mocha-theme into ~/.local/state/mocha-shell/theme.json).
Singleton {
    id: root

    // ── Catppuccin Mocha ────────────────────────────────────────────
    readonly property color rosewater: "#f5e0dc"
    readonly property color flamingo: "#f2cdcd"
    readonly property color pink: "#f5c2e7"
    readonly property color mauve: "#cba6f7"
    readonly property color red: "#f38ba8"
    readonly property color maroon: "#eba0ac"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color teal: "#94e2d5"
    readonly property color sky: "#89dceb"
    readonly property color sapphire: "#74c7ec"
    readonly property color blue: "#89b4fa"
    readonly property color lavender: "#b4befe"
    readonly property color text: "#cdd6f4"
    readonly property color subtext1: "#bac2de"
    readonly property color subtext0: "#a6adc8"
    readonly property color overlay2: "#9399b2"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay0: "#6c7086"
    readonly property color surface2: "#585b70"
    readonly property color surface1: "#45475a"
    readonly property color surface0: "#313244"
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"

    readonly property var accentNames: ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]

    // ── Accent (live) ───────────────────────────────────────────────
    readonly property string accentName: accentNames.indexOf(st.accent) >= 0 ? st.accent : "mauve"
    readonly property string accentMode: st.mode
    readonly property string wallpaper: st.wallpaper
    property color accent: root[accentName]
    Behavior on accent {
        ColorAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }
    readonly property color onAccent: crust
    readonly property color accentSoft: alpha(accent, 0.16)
    readonly property color accentMuted: alpha(accent, 0.32)

    // ── Semantic surfaces ───────────────────────────────────────────
    readonly property color panel: alpha(base, 0.94)
    readonly property color panelSolid: base
    readonly property color panelBorder: alpha(surface1, 0.55)
    readonly property color layer1: surface0
    readonly property color layer2: surface1
    readonly property color hover: alpha(text, 0.07)
    readonly property color press: alpha(text, 0.12)
    readonly property color textMuted: subtext0
    readonly property color textFaint: overlay1
    readonly property color danger: red
    readonly property color success: green
    readonly property color warning: yellow

    // ── Type ────────────────────────────────────────────────────────
    // The whole shell UI is set in the system mono font (JetBrains Mono NF).
    readonly property string fontSans: fontMono
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontIcon: "Material Symbols Rounded"
    readonly property int fontXs: 11
    readonly property int fontSm: 12
    readonly property int fontMd: 13
    readonly property int fontLg: 15
    readonly property int fontXl: 18

    // ── Geometry (kept in sync with Hyprland: gaps_out 12, rounding 14) ──
    readonly property int gap: 12          // screen-edge gap
    readonly property int spacing: 8
    readonly property int pad: 12
    readonly property int radius: 14       // windows, islands, panels
    readonly property int radiusSm: 10     // controls inside panels
    readonly property int radiusXs: 6
    readonly property int barHeight: 38
    readonly property int iconSize: 18

    // ── Motion ──────────────────────────────────────────────────────
    readonly property int animFast: 140
    readonly property int animNormal: 240
    readonly property int animSlow: 420
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveDecel: [0.05, 0.7, 0.1, 1, 1, 1]

    // ── Paths ───────────────────────────────────────────────────────
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/state/mocha-shell"
    readonly property string stateFile: Quickshell.env("MOCHA_THEME_FILE") || (stateDir + "/theme.json")
    readonly property string scripts: Quickshell.shellPath("scripts")
    readonly property string wallpaperDir: home + "/Pictures/Wallpapers/catppuccin-mocha"
    readonly property string thumbDir: home + "/.cache/mocha-shell/thumbs"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function mix(a, b, t) {
        return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, a.a * (1 - t) + b.a * t);
    }
    // Run the theme engine (set wallpaper, change accent, …)
    function themeCmd(args) {
        Quickshell.execDetached([scripts + "/mocha-theme"].concat(args));
    }
    function setWallpaper(path) {
        themeCmd(["set", path]);
    }
    function setAccent(name) {
        themeCmd(["accent", name]);
    }

    FileView {
        path: root.stateFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: st
            property string accent: "mauve"
            property string mode: "auto"
            property string wallpaper: ""
        }
    }
}
