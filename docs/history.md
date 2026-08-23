# History — Mixomancer groundwork

How the shop music path existed **before** this Rails app. Meadow Circle is one LAN (house front, shop back). See RobShare `notes/site.md`.

## 2026-08-22 / 23

1. **haruna Bluetooth** — Intel 3165 `hci0` was present but `bluez` was not installed. Installed `bluez` + `bluez-utils`; adapter `B4:69:21:E9:B0:C8`, powered.
2. **Soundbar hunt** — TCL S45H (`tcl_B14S45H0_199C`) advertised BLE only; A2DP pair failed (not in pairing mode). **P27** (`F4:4E:FD:4D:7D:B9`) paired as an A2DP sink.
3. **A2DP on a headless box** — WirePlumber treated linger as seat “closing” and never registered A2DP (`Protocol not available`). Drop-in `/etc/wireplumber/wireplumber.conf.d/51-headless-bluetooth.conf` disables logind seat-monitoring. Played a test WAV through P27 (`bluez_output.F4_4E_FD_4D_7D_B9.1`).
4. **Library** — gluttony has no `/usr/share/sounds`. NAS WAVs live at `/mnt/tnas/md1/appdata/audio_cds` (also `/srv/nfs/appdata/audio_cds`): seven guitar tracks plus hour-long forest / rain / songbirds loops.
5. **NFS client** — haruna mounts `192.168.72.2:/appdata/audio_cds` at `/mnt/audio_cds` (NFSv4.2, fstab + systemd automount).
6. **mpv queue** — `audio-cds-queue.service` (user `rob`) plays `/home/rob/audio-cds-queue/playlist.m3u` with mpv, looping. First run used Bluetooth; P27 dropped and audio fell through to `auto_null`. Queue stopped. Output moved to the **built-in analog HP jack** (`alsa_output.pci-0000_00_0e.0.analog-stereo`); `rob` added to group `audio`; Master unmuted 80%.
7. **This repo** — Rails 8.1.3 / Ruby 4.0.6 via **mise** on haruna (Node 24.18.0). JS packages use **aube** (jdx, [aube.jdx.dev](https://aube.jdx.dev)), not Yarn. Dev server on `:3000`.

## Playlist order (mpv unit)

1. `calming_guitar` (7 WAVs)
2. `calming_forest_sounds/Track 1.wav`
3. `calming_rain_and_thunder/Track 1.wav`
4. `calming_songbirds/Track 1.wav`

Then loop.
