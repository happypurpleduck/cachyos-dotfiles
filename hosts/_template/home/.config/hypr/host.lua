-- HOSTNAME — loaded at the end of ~/.config/hypr/hyprland.lua (shared config).
-- Monitor names/modes: `hyprctl monitors all`. Wiki: https://wiki.hypr.land/configuring/core/monitors/

-- hl.monitor({ output = "DP-1", mode = "highrr", position = "0x0", scale = 1 })

-- Pin workspaces to monitors (optional):
-- for i = 1, 9 do hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1" }) end

-- NVIDIA only:
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("NVD_BACKEND", "direct")

-- Laptop: touchpad, per-device input
-- hl.config({ input = { touchpad = { natural_scroll = true } } })

return {
	autostart = function()
		-- hl.exec_cmd("sleep 3 && discord --start-minimized")
	end,
}
