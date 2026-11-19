-- husain-pc — RTX 4070 Ti, two 1440p/144 Hz monitors.
-- Loaded at the end of ~/.config/hypr/hyprland.lua (shared config).

-- Left: ASUS VG27AQL1A over DisplayPort
hl.monitor({
	output = "DP-2",
	mode = "highrr", -- highest refresh rate at the highest resolution (1440p @ 144)
	position = "0x0",
	-- scale = 1.6, -- 2560x1440 / 1.6 = 1600x900 logical
})

-- Right: via the KVM switch over HDMI (reports itself as "General Information Systems VI-01")
hl.monitor({
	output = "HDMI-A-1",
	mode = "highrr",
	position = "2560x0", -- logical coords: right after the left monitor
	-- position = "1600x0", -- with scale 1.6 on the left monitor
	-- scale = 1.6,
})

-- Workspaces 1–9 live on the right monitor and 10 (Super+0) on the left one,
-- whenever that monitor is connected; otherwise they fall back to whatever is.
for i = 1, 9 do
	hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1", default = (i == 1) })
end
hl.workspace_rule({ workspace = "10", monitor = "DP-2", default = true, persistent = true })

-- NVIDIA
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Scaling for X11 apps: let them draw at the real resolution instead of upscaled
-- (blurry) when the monitors are scaled; Steam scales its own UI instead.
hl.config({ xwayland = { force_zero_scaling = true } })
-- hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.6")

return {
	autostart = function()
		-- Background apps, straight to the tray
		hl.exec_cmd("sleep 3 && steam -silent")
		hl.exec_cmd("sleep 3 && discord --start-minimized")
		-- T3 Code (nightly AppImage, self-updating) opens quietly on workspace 4
		hl.exec_cmd(
			"sleep 3 && exec ~/.local/opt/t3code/T3-Code.AppImage --password-store=gnome-libsecret",
			{ workspace = "4 silent" }
		)
	end,
}
