import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// Spotlight-style launcher.
//   (nothing)  apps · inline calculator when the query looks like maths
//   >          clipboard history          :  emoji
//   =          calculator                 @  wallpapers (grid)
//   /          actions (power, capture, accents, …)
OverlayWindow {
    id: win

    name: "launcher"
    open: Panels.launcher
    dim: 0.25
    onDismissed: Panels.launcher = false

    property string query: ""
    readonly property string prefix: [">", ":", "=", "@", "/"].includes(query.charAt(0)) ? query.charAt(0) : ""
    readonly property string term: prefix ? query.slice(1).trim() : query.trim()
    readonly property string mode: ({
            ">": "clipboard",
            ":": "emoji",
            "=": "calc",
            "@": "wallpaper",
            "/": "actions"
        })[prefix] ?? "apps"
    property string calcResult: ""
    property var emojiData: []

    onOpenChanged: {
        if (open) {
            query = Panels.launcherQuery;
            input.text = query;
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
            Clip.refresh();
        }
    }

    // ── result models ──────────────────────────────────────────────
    readonly property var results: {
        const t = term.toLowerCase();
        switch (mode) {
        case "clipboard":
            return Clip.entries.filter(e => !t || e.text.toLowerCase().includes(t)).slice(0, 80).map(e => ({
                        kind: "clip",
                        title: e.isImage ? "Image" : e.text,
                        sub: e.isImage ? e.text.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : "",
                        image: e.isImage ? "file://" + e.image : "",
                        icon: e.isImage ? "image" : "content_paste",
                        data: e
                    }));
        case "emoji":
            return emojiData.filter(e => !t || e.n.includes(t) || e.g.toLowerCase().includes(t)).slice(0, 60).map(e => ({
                        kind: "emoji",
                        title: e.n,
                        sub: e.g,
                        glyph: e.e,
                        data: e
                    }));
        case "calc":
            return term ? [
                {
                    kind: "calc",
                    title: calcResult || "…",
                    sub: term + "  ·  Enter to copy",
                    icon: "calculate"
                }
            ] : [];
        case "wallpaper":
            return wallpapers.filter(w => !t || w.toLowerCase().includes(t)).map(w => ({
                        kind: "wallpaper",
                        title: w,
                        data: w
                    }));
        case "actions":
            return actionList.filter(a => !t || (a.title + " " + a.keys).toLowerCase().includes(t));
        default:
            {
                const apps = Apps.search(term).slice(0, 50).map(a => ({
                            kind: "app",
                            title: a.name,
                            sub: a.comment || a.genericName || "",
                            iconName: a.icon,
                            data: a
                        }));
                if (calcResult && /^[\d\s.+\-*/^%()]+$/.test(term) && /[+\-*/^%]/.test(term))
                    apps.unshift({
                        kind: "calc",
                        title: calcResult,
                        sub: term + "  ·  Enter to copy",
                        icon: "calculate"
                    });
                return apps;
            }
        }
    }

    readonly property var actionList: {
        const a = [
            {
                title: "Lock",
                keys: "lock screen",
                icon: "lock",
                run: () => Session.lock()
            },
            {
                title: "Suspend",
                keys: "sleep",
                icon: "bedtime",
                run: () => Session.suspend()
            },
            {
                title: "Log out",
                keys: "logout exit",
                icon: "logout",
                run: () => Session.logout()
            },
            {
                title: "Reboot",
                keys: "restart",
                icon: "restart_alt",
                run: () => Session.reboot()
            },
            {
                title: "Shut down",
                keys: "poweroff shutdown",
                icon: "power_settings_new",
                run: () => Session.poweroff()
            },
            {
                title: "Screenshot (click a window or drag a region)",
                keys: "capture",
                icon: "screenshot_region",
                run: () => Capture.region()
            },
            {
                title: "Screenshot screen",
                keys: "capture",
                icon: "screenshot_monitor",
                run: () => Capture.screen()
            },
            {
                title: "Record screen",
                keys: "video capture",
                icon: "screen_record",
                run: () => Recorder.toggle("screen")
            },
            {
                title: "Colour picker",
                keys: "color hex",
                icon: "colorize",
                run: () => Capture.pickColor()
            },
            {
                title: "Random wallpaper",
                keys: "shuffle background",
                icon: "shuffle",
                run: () => Theme.themeCmd(["random"])
            },
            {
                title: "Accent: automatic",
                keys: "theme colour auto",
                icon: "auto_awesome",
                run: () => Theme.setAccent("auto")
            },
            {
                title: "Game mode",
                keys: "performance",
                icon: "sports_esports",
                run: () => Toggles.toggleGameMode()
            },
            {
                title: "Keep awake",
                keys: "caffeine idle",
                icon: "coffee",
                run: () => Toggles.toggleCaffeine()
            },
            {
                title: "Do not disturb",
                keys: "dnd notifications",
                icon: "do_not_disturb_on",
                run: () => Notifs.toggleDnd()
            }
        ];
        for (const n of Theme.accentNames)
            a.push({
                title: "Accent: " + n,
                keys: "theme colour " + n,
                icon: "palette",
                swatch: Theme[n],
                run: () => Theme.setAccent(n)
            });
        return a.map(x => Object.assign({
                kind: "action",
                sub: ""
            }, x));
    }

    property var wallpapers: []
    Process {
        running: win.open && win.wallpapers.length === 0
        command: ["sh", "-c", `cd "${Theme.wallpaperDir}" && ls -1 | grep -iE '\\.(jpe?g|png|webp|gif)$'`]
        stdout: StdioCollector {
            onStreamFinished: win.wallpapers = text.trim().split("\n").filter(s => s)
        }
    }
    FileView {
        path: Quickshell.shellPath("data/emoji.json")
        blockLoading: false
        onLoaded: win.emojiData = JSON.parse(text())
    }

    // calculator via qalc (libqalculate); falls back to a sanitised JS eval
    Process {
        id: qalc
        property string pending: ""
        stdout: StdioCollector {
            onStreamFinished: win.calcResult = text.trim().split("\n").pop()
        }
        onExited: (code, status) => {
            if (code !== 0)
                win.calcResult = win.jsCalc(qalc.pending);
        }
    }
    function jsCalc(e) {
        if (!/^[\d\s.+\-*/^%()]+$/.test(e))
            return "";
        try {
            const v = Function(`"use strict"; return (${e.replace(/\^/g, "**")})`)();
            return Number.isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (err) {
            return "";
        }
    }
    Timer {
        id: calcDebounce
        interval: 120
        onTriggered: {
            const e = win.term;
            if (!e || (win.mode === "apps" && !/[+\-*/^%]/.test(e))) {
                win.calcResult = "";
                return;
            }
            qalc.pending = e;
            qalc.command = ["qalc", "-t", e];
            qalc.running = true;
        }
    }
    onTermChanged: calcDebounce.restart()

    // ── activation ─────────────────────────────────────────────────
    function activate(item) {
        if (!item)
            return;
        switch (item.kind) {
        case "app":
            Apps.launch(item.data);
            break;
        case "clip":
            Clip.copy(item.data);
            break;
        case "emoji":
            Quickshell.execDetached(["wl-copy", item.glyph]);
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", item.title]);
            break;
        case "wallpaper":
            Theme.setWallpaper(Theme.wallpaperDir + "/" + item.data);
            return;            // stay open to try more wallpapers
        case "action":
            Panels.launcher = false;
            item.run();
            return;
        }
        Panels.launcher = false;
    }

    // ── UI ─────────────────────────────────────────────────────────
    Surface {
        id: card
        width: win.mode === "wallpaper" ? 900 : 640
        height: Math.min(header.height + body.implicitHeight + 24, win.mode === "wallpaper" ? 620 : 560)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16 - (1 - win.progress) * 24
        opacity: win.progress
        Behavior on width {
            Anim {}
        }
        Behavior on height {
            Anim {
                duration: Theme.animFast
            }
        }

        MouseArea {
            anchors.fill: parent
        }   // swallow clicks so the backdrop doesn't close us

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 14
                spacing: 12

                MIcon {
                    icon: ({
                            apps: "search",
                            clipboard: "content_paste",
                            emoji: "mood",
                            calc: "calculate",
                            wallpaper: "wallpaper",
                            actions: "bolt"
                        })[win.mode]
                    size: 22
                    color: Theme.accent
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontXl
                    selectionColor: Theme.accentMuted
                    selectedTextColor: Theme.text
                    clip: true
                    onTextChanged: {
                        win.query = text;
                        list.currentIndex = 0;
                        grid.currentIndex = 0;
                    }

                    StyledText {
                        anchors.fill: parent
                        visible: !input.text
                        text: "Search apps   ·   >  clipboard   :  emoji   =  calc   @  wallpapers   /  actions"
                        color: Theme.overlay0
                        font.pixelSize: Theme.fontMd
                    }

                    Keys.onPressed: e => {
                        const view = win.mode === "wallpaper" ? grid : list;
                        const n = win.results.length;
                        if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier)) || (e.key === Qt.Key_J && e.modifiers & Qt.ControlModifier)) {
                            view === grid ? grid.moveCurrentIndexDown() : list.incrementCurrentIndex();
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (e.key === Qt.Key_K && e.modifiers & Qt.ControlModifier)) {
                            view === grid ? grid.moveCurrentIndexUp() : list.decrementCurrentIndex();
                            e.accepted = true;
                        } else if (view === grid && e.key === Qt.Key_Right && input.cursorPosition === input.text.length) {
                            grid.moveCurrentIndexRight();
                            e.accepted = true;
                        } else if (view === grid && e.key === Qt.Key_Left && input.cursorPosition === input.text.length) {
                            grid.moveCurrentIndexLeft();
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            win.activate(win.results[view.currentIndex]);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Delete && win.mode === "clipboard" && n > 0) {
                            Clip.remove(win.results[list.currentIndex].data);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Escape) {
                            Panels.launcher = false;
                            e.accepted = true;
                        }
                    }
                }

                StyledText {
                    visible: win.mode !== "apps"
                    text: ({
                            clipboard: "Del removes",
                            wallpaper: Theme.accentName,
                            emoji: "Enter copies",
                            calc: "",
                            actions: ""
                        })[win.mode] ?? ""
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 1
                color: Theme.surface0
            }
        }

        Item {
            id: body
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            implicitHeight: win.mode === "wallpaper" ? Math.min(grid.contentHeight, 540) : Math.max(list.contentHeight, win.results.length === 0 ? 56 : 0)

            StyledText {
                anchors.centerIn: parent
                visible: win.results.length === 0
                text: win.mode === "clipboard" ? "Clipboard is empty" : win.mode === "calc" ? "Type an expression" : "No results"
                color: Theme.overlay1
            }

            ListView {
                id: list
                anchors.fill: parent
                visible: win.mode !== "wallpaper"
                clip: true
                model: win.mode !== "wallpaper" ? win.results : []
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Theme.animFast
                highlight: Rectangle {
                    radius: Theme.radiusSm
                    color: Theme.surface0
                    Rectangle {
                        width: 3
                        height: 18
                        radius: 2
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                    }
                }
                delegate: ResultRow {
                    width: list.width
                    onClicked: win.activate(modelData)
                    onHovered: list.currentIndex = index
                }
            }

            GridView {
                id: grid
                anchors.fill: parent
                visible: win.mode === "wallpaper"
                clip: true
                model: win.mode === "wallpaper" ? win.results : []
                cellWidth: width / 4
                cellHeight: cellWidth * 9 / 16 + 10
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    readonly property bool applied: modelData.kind === "wallpaper" && Theme.wallpaper.endsWith("/" + modelData.data)
                    width: grid.cellWidth
                    height: grid.cellHeight

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.radiusSm
                        color: Theme.surface0
                        border.width: tile.current || tile.applied ? 2 : 0
                        border.color: tile.current ? Theme.accent : Theme.overlay1
                        Image {
                            anchors.fill: parent
                            anchors.margins: tile.current || tile.applied ? 2 : 0
                            source: tile.modelData.kind === "wallpaper" ? `file://${Theme.thumbDir}/${tile.modelData.data}.jpg` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 384
                        }
                        Rectangle {
                            visible: tile.applied
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            width: 22
                            height: 22
                            radius: 11
                            color: Theme.accent
                            MIcon {
                                anchors.centerIn: parent
                                icon: "check"
                                size: 15
                                weight: 700
                                color: Theme.onAccent
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = tile.index
                        onClicked: win.activate(tile.modelData)
                    }
                }
            }
        }
    }
}
