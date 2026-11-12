pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Application search with fuzzy matching and launch-frequency ranking.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // subsequence fuzzy score; higher is better, -1 = no match
    function fuzzy(q, s) {
        s = s.toLowerCase();
        if (s.startsWith(q))
            return 1000 - s.length;
        const idx = s.indexOf(q);
        if (idx >= 0)
            return 700 - idx * 4 - s.length;
        let qi = 0, score = 0, streak = 0;
        for (let i = 0; i < s.length && qi < q.length; i++) {
            if (s[i] === q[qi]) {
                qi++;
                streak++;
                score += 10 + streak * 6 + (i === 0 || " -_.".includes(s[i - 1]) ? 25 : 0);
            } else {
                streak = 0;
            }
        }
        return qi === q.length ? score : -1;
    }

    function search(query) {
        const q = query.trim().toLowerCase();
        const counts = usage.counts || {};
        if (!q)
            return all.slice().sort((a, b) => (counts[b.id] || 0) - (counts[a.id] || 0) || a.name.localeCompare(b.name));
        const scored = [];
        for (const a of all) {
            let s = fuzzy(q, a.name);
            const g = Math.max(fuzzy(q, a.genericName || ""), fuzzy(q, (a.keywords || []).join(" ")), fuzzy(q, a.id || "")) - 120;
            s = Math.max(s, g);
            if (s >= 0)
                scored.push({
                    a,
                    s: s + Math.min(200, (counts[a.id] || 0) * 15)
                });
        }
        return scored.sort((x, y) => y.s - x.s).map(x => x.a);
    }

    function launch(entry) {
        const c = Object.assign({}, usage.counts || {});
        c[entry.id] = (c[entry.id] || 0) + 1;
        usage.counts = c;
        usageFile.writeAdapter();
        if (entry.runInTerminal) {
            const cmd = entry.execString.replace(/\s*%[fFuUdDnNickvm]/g, "");
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", cmd]);
        } else {
            entry.execute();
        }
    }

    FileView {
        id: usageFile
        path: Theme.stateDir + "/apps.json"
        printErrors: false
        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }
}
