-- husain-parcel — two Samsung C24F390 (1080p) monitors over HDMI.
-- Loaded at the end of ~/.config/hypr/hyprland.lua (shared config).
-- Monitor names/modes: `hyprctl monitors all`. Wiki: https://wiki.hypr.land/configuring/core/monitors/
--
-- Both monitors are the same model, and the HDMI-A-N connector names can shuffle
-- between boots/docks, so each one is matched by its description (incl. serial).

local LEFT = "desc:Samsung Electric Company C24F390 H4ZNA01738" -- currently HDMI-A-4
local RIGHT = "desc:Samsung Electric Company C24F390 H4ZNA01933" -- currently HDMI-A-1

-- Left
hl.monitor({
	output = LEFT,
	mode = "highres", -- highest resolution, then its highest refresh (1080p @ 71.91); highrr picks 640x480@72.8
	position = "0x0",
})

-- Right
hl.monitor({
	output = RIGHT,
	mode = "highres",
	position = "1920x0", -- right after the left monitor
})

-- Workspaces 1–9 live on the right monitor and 10 (Super+0) on the left one,
-- whenever that monitor is connected; otherwise they fall back to whatever is.
for i = 1, 9 do
	hl.workspace_rule({ workspace = tostring(i), monitor = RIGHT, default = (i == 1) })
end
hl.workspace_rule({ workspace = "10", monitor = LEFT, default = true, persistent = true })

-- Laptop: touchpad, per-device input
-- hl.config({ input = { touchpad = { natural_scroll = true } } })

return {
	autostart = function()
		-- hl.exec_cmd("sleep 3 && discord --start-minimized")
	end,
}
