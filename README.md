# Mixomancer

Household DJ for Meadow Circle. A Ruby on Rails server that will run the shop/house music queue — playlists of CDs and library folders, out analog jack or Bluetooth, on a shop box.

The name is **mixomancer** (a wizard who mixes). Not Mixalot / Sir Mix-a-Lot.

GitHub is canonical when the GitHub repo exists. LAN bare: `git@gluttony:Ruby-on-Rails-Wizardry/mixomancer.git`.

## What we have already (before this Rails app)

Work landed on **haruna** (`192.168.72.3`) and **gluttony** (`192.168.72.2`):

| Piece | Where | Notes |
|-------|--------|--------|
| Library | gluttony `/mnt/4tb/a/md1/appdata/audio_cds` | 4 CD rips: guitar + forest + rain + songbirds (WAV). `/mnt/tnas/md1/appdata` is an empty stub. |
| NFS | haruna `/mnt/audio_cds` | `192.168.72.2:/appdata/audio_cds` (NFSv4.2, systemd automount) |
| Player | haruna `audio-cds-queue.service` (user `haruna`) | mpv + m3u, **analog HP jack** |
| Playlist | `/var/lib/mixomancer/playlist.m3u` | guitar tracks, then forest, rain, songbirds; loops |
| Bluetooth | haruna `bluez` + P27 (`F4:4E:FD:4D:7D:B9`) | paired; A2DP worked; jack is the current output |
| Audio stack | PipeWire + WirePlumber (user `haruna`, linger) | headless seat-monitoring disabled so ALSA/A2DP register |

This Rails app is the next layer: a server UI and API in front of that queue, instead of only a systemd unit.

## Production (haruna)

The live process is the machine account **haruna** (uid 2003), not `rob`. Code runs from `/opt/mixomancer`. `RAILS_ENV=production`.

Thruster listens on port 80 and proxies to Puma on `127.0.0.1:3000`. Nothing else on this host wants port 80, so there is no separate nginx or Caddy. LAN URLs: **http://haruna.lan** and **http://mixomancer.lan**.

```bash
sudo systemctl restart mixomancer audio-cds-queue mixomancer-kiosk
```

PipeWire for this box belongs to `haruna` (`loginctl enable-linger haruna`). `rob`'s user PipeWire and the old development `mixomancer.service` stay disabled so they do not take the sound card or port 3000.

`bin/dev` is still the local development server. It is not what haruna runs.

## Docs

- [docs/production.md](docs/production.md) — live layout, deploy, and traps
- [docs/history.md](docs/history.md) — how we got here (NFS, mpv, Bluetooth, analog)
- [AGENTS.md](AGENTS.md) — agent playbook
