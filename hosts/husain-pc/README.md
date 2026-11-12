# husain-pc

Desktop: Ryzen + RTX 4070 Ti, CachyOS, two 1440p/144 Hz monitors.

| File | What |
|---|---|
| `home/.config/hypr/host.lua` | DP-2 = ASUS VG27AQL1A (left, workspace 10 only), HDMI-A-1 = KVM (right, workspaces 1–9); NVIDIA env; Steam / Discord / T3 Code autostart |
| `home/.config/mocha-shell/host.json` | names for the Moondrop Chu 2 (KTMicro CDSP) and motherboard audio; AutoEq on the CDSP; RNNoise on the DCMT USB condenser mic |
| `home/.config/pipewire/mocha-autoeq.conf*`, `autoeq/` | Chu 2 AutoEq filter (crinacle B&K 4620 target) |
| `home/.config/obs-studio/` | OBS "Mocha" profile + scenes (NVENC HEVC). The stream key (`service.json`) is never committed — paste it in OBS after installing |
| `home/.config/autostart/` | Kanihara (local dev build) |
| `packages.txt` / `aur.txt` | everything else installed here (`dot packages`) |

## Notes

- Steam library: Samsung 860 EVO, btrfs subvolume `@steam` mounted at `/mnt/steam`:
  `UUID=fc664ecc-8b56-46bc-bc5f-4657eb391ca5 /mnt/steam btrfs subvol=@steam,defaults,noatime,compress=zstd:1,nofail,x-systemd.device-timeout=10s 0 0`
- F22 (keycode 200) mutes every mic — bound in the shared config, harmless elsewhere.
