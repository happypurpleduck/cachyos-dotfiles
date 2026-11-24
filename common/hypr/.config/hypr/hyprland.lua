-- Hyprland (Lua config) — shared by every machine in ~/cachyos-dotfiles.
--
-- Machine-specific bits (monitors, which workspace lives where, GPU env vars,
-- apps to autostart) live in ~/.config/hypr/host.lua, which comes from
-- hosts/<hostname>/home/.config/hypr/host.lua in the repo. It runs at the end of this
-- file (so it can override anything here) and may return a table:
--   return { autostart = function() hl.exec_cmd("steam -silent") end }
-- Without a host.lua every monitor uses its preferred mode, placed automatically.
--
-- Wiki: https://wiki.hypr.land/configuring/

------------------
---- MONITORS ----
------------------

-- Fallback for any monitor the host file doesn't describe
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local fileManager = "nautilus --new-window"
-- Quickshell launcher, falling back to fuzzel if the shell isn't running
local menu = "qs ipc call launcher toggle || fuzzel"
local qs = "qs ipc call "

-- filled in by host.lua at the end of this file
local host = {}

-------------------
---- AUTOSTART ----
-------------------

-- Notifications (hokum) run as a systemd user service tied to
-- graphical-session.target, so they aren't started here. The polkit agent
-- lives inside the Quickshell shell.
hl.on("hyprland.start", function()
	-- apps started by systemd/D-Bus services (e.g. links from Hokum) get the same theme env
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd PATH EDITOR VISUALQT_QPA_PLATFORMTHEME QT_WAYLAND_DISABLE_WINDOWDECORATION XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE"
	)

	-- Wallpaper + accent: awww daemon, then mocha-theme restores the last
	-- wallpaper and re-applies the matching accent everywhere
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("~/.config/quickshell/scripts/mocha-theme restore")

	-- The desktop shell (bar, launcher, lock, OSD, polkit, …)
	hl.exec_cmd("qs")

	-- Clipboard history (text + images) and persistence after source app closes
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("wl-clip-persist --clipboard regular")

	-- this machine's own autostart apps
	if host.autostart then
		host.autostart()
	end
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- A failed optional cursor download must not break first login. Adwaita is
-- supplied by the CachyOS desktop stack and remains the safe fallback.
local cursorTheme = "Adwaita"
local cursorHome = os.getenv("HOME")
if cursorHome then
  local cursorFile = io.open(cursorHome .. "/.local/share/icons/catppuccin-mocha-dark-cursors/index.theme", "r")
  if cursorFile then
    cursorFile:close()
    cursorTheme = "catppuccin-mocha-dark-cursors"
  end
end
hl.env("XCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_THEME", cursorTheme)

-- Qt apps follow the generated Mocha palette (qt6ct), GTK apps via gtk.css
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- User tools (same as ~/.zshenv) so desktop entries and binds can run
-- ~/.local/bin scripts such as t3code-launch. Guarded so reloads don't stack it.
local pathHome = os.getenv("HOME")
local sessionPath = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if pathHome and not (":" .. sessionPath .. ":"):find(":" .. pathHome .. "/.local/bin:", 1, true) then
	hl.env("PATH", pathHome .. "/.local/bin:" .. pathHome .. "/.local/share/mise/shims:" .. sessionPath)
end

-- Editors (same as ~/.zshenv) for apps launched from the desktop
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "zed --wait")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/configuring/core/advanced-configuration/permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/configuring/core/config-options/
hl.config({
	general = {
		-- Matches the shell: 12px screen-edge gap, 6px between windows
		gaps_in = 6,
		gaps_out = 12,

		border_size = 2,

		-- Border colours come from mocha-theme.lua (accent follows the wallpaper)

		-- Set to true to enable resizing windows by clicking and dragging on borders and gaps
		resize_on_border = false,

		-- Please see https://wiki.hypr.land/configuring/extra/tearing/ before you turn this on
		-- OFF: on NVIDIA, async (tearing) page-flips sometimes get rejected (EINVAL) when a
		-- fullscreen game regains focus, leaving the output stuck on a frame while the game
		-- keeps running (hit with MHW, 2026-11-15). The "immediate" game rules are inert while off.
		allow_tearing = false,

		layout = "dwindle",
	},

	decoration = {
		-- Same radius as the shell's islands and panels
		rounding = 14,
		rounding_power = 2,

		-- Change transparency of focused and unfocused windows
		active_opacity = 1.0,
		inactive_opacity = 1.0,

		dim_inactive = false,

		shadow = {
			enabled = true,
			range = 18,
			render_power = 3,
			offset = "0 6",
		},

		blur = {
			enabled = true,
			size = 6,
			passes = 3,
			noise = 0.012,
			contrast = 1.0,
			brightness = 0.9,
			vibrancy = 0.18,
			popups = true,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Generated Catppuccin Mocha colours (accent follows the wallpaper).
-- Rewritten by ~/.config/quickshell/scripts/mocha-theme; applied live too.
pcall(require, "mocha-theme")

-- Default curves and animations, see https://wiki.hypr.land/configuring/core/animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Default springs
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "easeOutQuint" })
-- Toned down: short ease-out, no spring overshoot, subtle pop-in (speed is in 100 ms units)
hl.animation({ leaf = "windows", enabled = true, speed = 2.4, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.2, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "easeOutQuint", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.3, bezier = "linear", style = "popin 95%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.6, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.6, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- Ref https://wiki.hypr.land/configuring/core/rules/workspace-rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/configuring/layouts/dwindle-layout/ for more
hl.config({
	dwindle = {
		preserve_split = true, -- You probably want this
	},
})

-- See https://wiki.hypr.land/configuring/layouts/master-layout/ for more
hl.config({
	master = {
		new_status = "master",
	},
})

-- See https://wiki.hypr.land/configuring/layouts/scrolling-layout/ for more
hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = 0, -- awww draws the wallpaper
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		-- if the shell's lock screen ever crashes, a restarted shell may take over the lock
		allow_session_lock_restore = true,
	},
})

----------------
---- LAYERS ----
----------------

hl.config({
	layers = {
		allow_new_top_layers_over_existing_fullscreen = true, -- Set to false to make newly mapped top layers render below existing covering fullscreen window
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us,ara", -- English + Arabic; Super+Space switches
		kb_variant = "",
		kb_model = "",
		kb_options = "grp:win_space_toggle",
		kb_rules = "",

		follow_mouse = 1,

		sensitivity = -1.0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = false,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- Per-device input settings belong in host.lua (hl.device({ name = …, … })).

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/configuring/core/binds/ for more
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + backslash", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
-- Power menu (Lock is preselected: Super+Esc, Enter locks). No plain-exit fallback,
-- so a stray key can never end the session.
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(qs .. "session toggle"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(menu))

-- ── Mocha shell ─────────────────────────────────────────────────────
hl.bind(
	mainMod .. " + SHIFT + V",
	hl.dsp.exec_cmd(qs .. "launcher clipboard || (cliphist list | fuzzel --dmenu | cliphist decode | wl-copy)")
)
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(qs .. "launcher emoji"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(qs .. "launcher wallpaper"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/quickshell/scripts/mocha-theme random"))
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd(qs .. "launcher actions"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(qs .. "controlcenter toggle"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd(qs .. "overview toggle"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd(qs .. "switcher next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(qs .. "switcher prev"))
-- F22: mute / unmute every microphone (popup + chime). Bound by keycode: xkb names
-- F22 "XF86TouchpadOn", so a "F22" keysym bind would never fire. Works on the lock
-- screen and while a game inhibits shortcuts.
hl.bind(
	"code:200",
	hl.dsp.exec_cmd(qs .. "mic muteAll"),
	{ locked = true, dont_inhibit = true, description = "Mute all microphones" }
)
hl.bind("Print", hl.dsp.exec_cmd(qs .. "capture region"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(qs .. "capture screen"))
hl.bind("ALT + Print", hl.dsp.exec_cmd(qs .. "capture window"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(qs .. "capture menu"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(qs .. "record region"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(qs .. "capture color"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + S", hl.dsp.layout("togglesplit")) -- dwindle only

-- Move focus with mainMod + arrows or vim keys (h j k l);
-- add SHIFT to move the window in that direction
local directions = {
	{ "left", "h" },
	{ "right", "l" },
	{ "up", "k" },
	{ "down", "j" },
}
for _, d in ipairs(directions) do
	local dir, vim = d[1], d[2]
	hl.bind(mainMod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
	hl.bind(mainMod .. " + " .. vim, hl.dsp.focus({ direction = dir }))
	hl.bind(mainMod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
	hl.bind(mainMod .. " + SHIFT + " .. vim, hl.dsp.window.move({ direction = dir }))
end

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad) — disabled; Super+S toggles the split instead
-- hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/configuring/core/rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

-- Small utility windows float, centred
hl.window_rule({
	name = "float-utilities",
	match = {
		class = "^(com.gabm.satty|hokum|waypaper|nwg-look|qt6ct|qt5ct|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor|xdg-desktop-portal-gtk)$",
	},
	float = true,
	center = true,
})

-- Desktop utilities: float, centred, sized as a fraction of the monitor so the same
-- rules fit any machine (on a 2560x1440 monitor 0.5 x 0.6 = 1280x864).
-- No size = the app picks its own (Calculator resizes itself per mode).
local utilityApps = {
	{ name = "calculator", class = "org.gnome.Calculator" },
	{ name = "image-viewer", class = "org.gnome.Loupe", size = { 0.6, 0.7 } },
	{ name = "quick-preview", class = "org.gnome.NautilusPreviewer", size = { 0.55, 0.65 } }, -- Space in Nautilus
	{ name = "archives", class = "org.gnome.FileRoller", size = { 0.36, 0.42 } },
	{ name = "disk-usage", class = "org.gnome.baobab", size = { 0.45, 0.55 } },
	{ name = "disks", class = "org.gnome.DiskUtility", size = { 0.42, 0.5 } },
	{ name = "task-manager", class = "io.missioncenter.MissionCenter", size = { 0.5, 0.6 } },
}
for _, app in ipairs(utilityApps) do
	hl.window_rule({
		name = "utility-" .. app.name,
		match = { class = "^" .. app.class:gsub("%.", "\\.") .. "$" },
		float = true,
		center = true,
		size = app.size and string.format("monitor_w*%s monitor_h*%s", app.size[1], app.size[2]) or nil,
	})
end

-- Browser picture-in-picture (Chrome "Picture in picture", Firefox "Picture-in-Picture"):
-- small, pinned on every workspace, tucked into the bottom-right corner
hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture[ -]in[ -][Pp]icture)$" },
	float = true,
	pin = true,
	keep_aspect_ratio = true,
	size = "monitor_w*0.25 monitor_h*0.25",
	move = "monitor_w-window_w-24 monitor_h-window_h-24",
})

-- Games: Steam games (steam_app_*), gamescope and anything that tags itself as a
-- game go truly fullscreen, skip compositor latency (tearing allowed) and keep the
-- idle lock / screen-off from kicking in mid-game.
hl.window_rule({
	name = "games-fullscreen",
	match = { class = "^(steam_app_\\d+|gamescope)$" },
	fullscreen = true,
	immediate = true,
	idle_inhibit = "always",
})
hl.window_rule({
	name = "games-content-type",
	match = { content = "game" },
	immediate = true,
	idle_inhibit = "always",
})
-- Anything fullscreen (videos, games, browser fullscreen) holds off the idle lock
hl.window_rule({
	name = "fullscreen-idle-inhibit",
	match = { class = ".*" },
	idle_inhibit = "fullscreen",
})

-- Steam's small dialogs float; the main window tiles
hl.window_rule({
	name = "steam-dialogs",
	match = {
		class = "^steam$",
		title = "^(Friends List|Steam Settings|Special Offers|Screenshot Manager|Steam - News.*|Game Servers|Players)$",
	},
	float = true,
	center = true,
})

-- mpv: open centred and floating at a sensible size (Super+F to maximise)
hl.window_rule({
	name = "mpv-float",
	match = { class = "^mpv$" },
	float = true,
	center = true,
	size = "1600 900",
})

-- Mocha shell surfaces: blur what's behind the translucent panels.
-- ignore_alpha keeps fully transparent areas (gaps between bar islands,
-- the empty part of full-screen overlays) unblurred.
hl.layer_rule({
	name = "mocha-blur",
	match = {
		namespace = "^mocha-(bar|launcher|controlcenter|calendar|audiofx|bluetooth|osd|capture|switcher|polkit|btpair)$",
	},
	blur = true,
	ignore_alpha = 0.5,
})
hl.layer_rule({
	-- the power menu and overview dim the whole screen; blur it too
	name = "mocha-blur-fullscreen",
	match = { namespace = "^mocha-(session|overview)$" },
	blur = true,
	ignore_alpha = 0.3,
})
hl.layer_rule({
	-- panels animate themselves; skip Hyprland's layer animation
	name = "mocha-no-anim",
	match = { namespace = "^mocha-.*" },
	no_anim = true,
})
hl.layer_rule({ name = "hokum-blur", match = { namespace = "^hokum.*" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ name = "selection-no-anim", match = { namespace = "^(selection|hyprpicker)$" }, no_anim = true })

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

-- Alt-Tab: releasing Alt commits the switcher selection
hl.bind("ALT + ALT_L", hl.dsp.exec_cmd("qs ipc call switcher commit"), { release = true })

------------------
---- THIS HOST ----
------------------

-- ~/.config/hypr/host.lua (see the top of this file). Loaded last so it can override
-- anything above. A missing file is fine; an error inside it is not swallowed.
do
	local ok, res = pcall(require, "host")
	if ok then
		host = type(res) == "table" and res or {}
	elseif not tostring(res):find("module 'host' not found", 1, true) then
		error(res)
	end
end
