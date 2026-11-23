#!/usr/bin/env python3
"""First-party app installation is explicit, isolated and self-updating."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

repo = Path(__file__).resolve().parents[1]
path = repo / "scripts/upstream-apps.py"
spec = importlib.util.spec_from_file_location("upstream_apps", path)
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp) / "independent user"
    home.mkdir()
    bin_dir = home / ".local/bin"
    bin_dir.mkdir(parents=True)
    env = {**os.environ, "HOME": str(home), "PATH": "/usr/bin:/bin"}
    with patch.dict(os.environ, env, clear=True):
        assert not app.app_state(home, "mise")["installed"]
        assert not app.app_state(home, "zed")["installed"]

        # Explicit vendor script acts in the target HOME; no real networking.
        mise_script = b"""#!/bin/sh
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/mise" <<'EOF'
#!/bin/sh
printf '%s' "$*" > "$HOME/updated"
EOF
chmod 755 "$HOME/.local/bin/mise"
"""
        zed_script = b"""#!/bin/sh
mkdir -p "$HOME/.local/zed.app/bin"
cat > "$HOME/.local/zed.app/bin/zed" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 755 "$HOME/.local/zed.app/bin/zed"
printf '%s' "$ZED_CHANNEL" > "$HOME/zed-channel"
"""
        with patch.object(app, "fetch_vendor_script", return_value=(mise_script, "https://mise.run")):
            app.install(home, "mise")
        with patch.object(app, "fetch_vendor_script", return_value=(zed_script, "https://zed.dev/install.sh")):
            app.install(home, "zed")
        assert app.app_state(home, "mise")["upstream_managed"]
        assert app.app_state(home, "zed")["upstream_managed"]
        assert (home / "zed-channel").read_text() == "stable"
        assert not (home / ".local/opt").exists(), "no AppImage or other assets were installed"

        # Re-installing an existing upstream-managed app is idempotent; do not fetch.
        with patch.object(app, "fetch_vendor_script", side_effect=AssertionError("duplicate download")):
            app.install(home, "mise")
            app.install(home, "zed")

        app.update(home, "mise")
        assert (home / "updated").read_text() == "self-update --yes --no-plugins"
        app.update(home, "zed")  # reports the upstream automatic updater

        # Reject mixing a pacman-managed binary with an upstream self-updater.
        (bin_dir / "mise").unlink()
        other = home / "otherbin"
        other.mkdir()
        external = other / "mise"
        external.write_text("#!/bin/sh\nexit 0\n")
        external.chmod(0o755)
        os.environ["PATH"] = str(other) + ":/usr/bin:/bin"
        with patch.object(app, "fetch_vendor_script", side_effect=AssertionError("must not fetch")):
            try:
                app.install(home, "mise")
            except ValueError as e:
                assert "mix pacman and upstream" in str(e)
            else:
                raise AssertionError("external mise binary accepted for self-managed install")
        try:
            app.update(home, "mise")
        except ValueError:
            pass
        else:
            raise AssertionError("externally managed mise self-update allowed")

    # Bad installer redirects and broken script content fail prior to execution.
    class Response:
        headers = {"Content-Length": "512"}
        def __init__(self, url, body):
            self.url = url
            self.body = body
        def __enter__(self):
            return self
        def __exit__(self, *_args):
            return False
        def geturl(self):
            return self.url
        def read(self, _size):
            return self.body
    with patch.object(app, "urlopen", return_value=Response(
        "http://evil.example/install.sh", b"#!/bin/sh\n" + b"#" * 500,
    )):
        try:
            app.fetch_vendor_script("mise")
        except ValueError as e:
            assert "untrusted installer redirect" in str(e)
        else:
            raise AssertionError("HTTP redirect accepted")
    with patch.object(app, "urlopen", return_value=Response(
        "https://mise.run", b"<html>" + b"x" * 500,
    )):
        try:
            app.fetch_vendor_script("mise")
        except ValueError as e:
            assert "not an expected shell installer" in str(e)
        else:
            raise AssertionError("HTML installer accepted")

    # The CLI's normal status remains offline and read-only.
    result = subprocess.run(
        [sys.executable, str(path), "--json", "status"],
        env={**os.environ, "HOME": str(home), "PATH": "/usr/bin:/bin"},
        text=True, capture_output=True, check=True,
    )
    state = json.loads(result.stdout)
    assert state["zed"]["upstream_managed"]
print("first-party apps: opt-in bootstrap, self-update and mixed-install guards: OK")
