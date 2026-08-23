# Mixomancer

Household DJ for Meadow Circle. A Ruby on Rails server that will run the shop/house music queue — playlists of CDs and library folders, out analog jack or Bluetooth, on a shop box.

The name is **mixomancer** (a wizard who mixes). Not Mixalot / Sir Mix-a-Lot.

GitHub is canonical when the GitHub repo exists. LAN bare: `git@gluttony:Ruby-on-Rails-Wizardry/mixomancer.git`.

## What we have already (before this Rails app)

Work landed on **haruna** (`192.168.72.3`) and **gluttony** (`192.168.72.2`):

| Piece | Where | Notes |
|-------|--------|--------|
| Library | gluttony `/mnt/tnas/md1/appdata/audio_cds` | 4 CD rips: guitar + forest + rain + songbirds (WAV) |
| NFS | haruna `/mnt/audio_cds` | `192.168.72.2:/appdata/audio_cds` (NFSv4.2, systemd automount) |
| Player | haruna `audio-cds-queue.service` (user `rob`) | mpv + m3u, currently **analog HP jack** |
| Playlist | `/home/rob/audio-cds-queue/playlist.m3u` | guitar tracks, then forest, rain, songbirds; loops |
| Bluetooth | haruna `bluez` + P27 (`F4:4E:FD:4D:7D:B9`) | paired; A2DP worked; jack is the current output |
| Audio stack | PipeWire + WirePlumber (user `rob`, linger) | headless seat-monitoring disabled so ALSA/A2DP register |

This Rails app is the next layer: a server UI and API in front of that queue, instead of only a systemd unit.

## Dev server (haruna)

Toolchain is **mise** on the host (not Docker):

- Ruby **4.0.6** (from `.ruby-version` / Gemfile)
- Node.js **24.18.0**
- **aube** ([aube.jdx.dev](https://aube.jdx.dev), `/ob/`) — jdx’s Node package manager (the JS counterpart to mise). Not Yarn/npm/pnpm.

```bash
ssh haruna
cd ~/Ruby-on-Rails-Wizardry/mixomancer
bin/dev          # puma + tailwind watch on :3000
```

LAN: **http://haruna.lan:3000** or **http://mixomancer.lan:3000** or **http://192.168.72.3:3000**.

User unit `mixomancer.service` starts `bin/dev` bound to `0.0.0.0:3000`.

```bash
systemctl --user -M rob@ start|stop|status mixomancer
```

## Docs

- [docs/history.md](docs/history.md) — how we got here (NFS, mpv, Bluetooth, analog)
- [AGENTS.md](AGENTS.md) — agent playbook
