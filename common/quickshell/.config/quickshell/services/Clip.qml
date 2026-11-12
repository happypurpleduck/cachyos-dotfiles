pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist. Image entries are decoded to small files
// under $XDG_RUNTIME_DIR so the launcher can show thumbnails.
Singleton {
    id: root

    property var entries: []      // [{line, id, text, isImage, image}]
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/mocha-clip"

    function refresh() {
        list.running = true;
    }
    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", entry.line]);
    }
    function remove(entry) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", entry.line]);
        entries = entries.filter(e => e.id !== entry.id);
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    Process {
        id: list
        command: ["sh", "-c", `mkdir -p "${root.cacheDir}"; cliphist list | head -n 300 | while IFS= read -r l; do
  id=\${l%%\t*}
  case "$l" in
    *"[[ binary data"*) f="${root.cacheDir}/$id.png"; [ -s "$f" ] || printf '%s' "$l" | cliphist decode > "$f" 2>/dev/null; printf '%s\t%s\n' "$l" "$f";;
    *) printf '%s\t\n' "$l";;
  esac
done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const raw of text.split("\n")) {
                    if (!raw)
                        continue;
                    const parts = raw.split("\t");
                    // parts: id, preview..., imagePath
                    const id = parts[0];
                    const image = parts[parts.length - 1];
                    const preview = parts.slice(1, parts.length - 1).join("\t");
                    out.push({
                        line: id + "\t" + preview,
                        id: id,
                        text: preview,
                        isImage: image !== "",
                        image: image
                    });
                }
                root.entries = out;
            }
        }
    }
}
