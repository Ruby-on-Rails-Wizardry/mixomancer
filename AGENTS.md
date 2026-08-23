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
| Dev host | haruna `192.168.72.3` / `haruna.lan` / `mixomancer.lan` |
| App path | `/home/rob/Ruby-on-Rails-Wizardry/mixomancer` |
| Ruby | 4.0.6 (mise + `.ruby-version`) |
| Node | 24.18.0 (mise) |
| aube | mise-managed ([aube.jdx.dev](https://aube.jdx.dev)) |
| Dev URL | `http://192.168.72.3:3000` |
| Library NFS | `/mnt/audio_cds` → gluttony `audio_cds` |
| Current mpv queue | `audio-cds-queue.service` (analog jack) |

## Common tasks

```bash
ssh haruna
cd ~/Ruby-on-Rails-Wizardry/mixomancer
bin/dev
# or:
systemctl --user -M rob@ restart mixomancer

git remote -v   # gluttony
git push gluttony
```
