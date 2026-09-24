# Agent playbook — Mixomancer

Household DJ / playlist server. Rails app. Dev host is **haruna** (`192.168.72.3`).

## Goals

1. Rails server in front of the shop music queue (NFS library on gluttony, player on haruna).
2. Do **not** name it Mixalot / Sir Mix-a-Lot.
3. GitHub canonical when the GitHub remote exists; LAN bare is `git@gluttony:Ruby-on-Rails-Wizardry/mixomancer.git`.
4. Host tools via **mise** (Ruby, Node) plus **aube** for JS packages (`mise use aube`). Do not install rbenv/nvm/volta/yarn in parallel.
5. Never commit secrets or `config/master.key`.

## Facts

| Item | Value |
|------|--------|
| Host | haruna `192.168.72.3` / `haruna.lan` / `mixomancer.lan` |
| Service user | `haruna` (uid 2003, machine account). Not `rob`. |
| App path | `/opt/mixomancer` (checkout may also exist under `rob`'s home) |
| Ruby | 4.0.6 (mise for user `haruna`) |
| URL | `http://haruna.lan` (Thruster on port 80, Puma on `127.0.0.1:3000`) |
| Library NFS | `/mnt/audio_cds` → gluttony `audio_cds` |
| State | `/var/lib/mixomancer` (playlist, session, video-current) |
| mpv queue | system unit `audio-cds-queue.service`, user `haruna`, analog jack |
| Audio | PipeWire user session of `haruna` (linger). Do not start `rob`'s PipeWire on this host. |
| Notes | [docs/production.md](docs/production.md) — layout, deploy, and the traps |

## Common tasks

```bash
ssh haruna
sudo systemctl restart mixomancer
sudo systemctl status mixomancer audio-cds-queue mixomancer-kiosk
```

Desk checkout remote is `origin`. Haruna checkout remote is `gluttony`. Same bare repo. Deploy steps and the reasons not to put this back on user `rob` are in [docs/production.md](docs/production.md).
