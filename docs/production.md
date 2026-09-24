# Production on haruna

Live as of 2026-09-24. Read this before restarting services or "fixing" the user back to `rob`.

## Layout

| What | Where |
|------|--------|
| Unix user | `haruna`, uid **2003**, gid 2003. GECOS "Machine account for haruna". There is no login named `haruna@haruna.lan`. |
| Groups | `audio`, `video`, `seat`, `render`, `input`, `systemd-journal` |
| Install | `/opt/mixomancer` (not a second git checkout; do not commit from here) |
| Git checkout on haruna | `/home/rob/Ruby-on-Rails-Wizardry/mixomancer`, remote name `gluttony` |
| Git checkout on a desk | same path, remote name `origin`. Both URLs are `git@gluttony:Ruby-on-Rails-Wizardry/mixomancer.git` |
| Ruby | mise for user `haruna`: `/home/haruna/.local/share/mise/installs/ruby/4.0.6` |
| Gems | `/opt/mixomancer/vendor/bundle`, `BUNDLE_WITHOUT=development:test` |
| Secret | `/opt/mixomancer/config/master.key`, mode 600, owner `haruna`. Not in git. |
| State | `/var/lib/mixomancer/` (`playlist.m3u`, `session.m3u`, `video-current`) |
| mpv sockets | `/run/user/2003/mpv-audio-cds.sock` and `mpv-video.sock` |
| Kiosk profile | `/home/haruna/.config/mixomancer-kiosk` (new profile; the Discord login stayed in `rob`'s old profile) |
| URL | `http://haruna.lan` and `http://mixomancer.lan` |

`/home/rob` is mode 700. The service user cannot read a checkout there, which is why the process runs from `/opt/mixomancer`.

## Processes

All of these are **system** units, `User=haruna`. Do not start the old user units under `rob`.

| Unit | Role |
|------|------|
| `mixomancer.service` | Thruster on **port 80**, Puma on `127.0.0.1:3000`, `RAILS_ENV=production` |
| `audio-cds-queue.service` | mpv playlist to the analog jack |
| `mixomancer-kiosk.service` | cage + Chromium on **tty7**, HDMI-A-2, `http://127.0.0.1/display` |
| `mixomancer-video.service` | HDMI video, same VT, started on demand |

PipeWire and WirePlumber are **user** units of `haruna` (`loginctl enable-linger haruna`). `rob`'s `pipewire.socket`, `pipewire-pulse.socket`, `wireplumber.service`, and `pipewire.service` are **masked** in `rob`'s user manager so they cannot take the sound card back. `rob`'s user `mixomancer.service` and `audio-cds-queue.service` are disabled. Leave them that way.

Sudo rules are `/etc/sudoers.d/mixomancer` (source: `systemd/sudoers-mixomancer`). The app calls `sudo -n systemctl` for the audio, kiosk, and video units.

## Library

NFS client line is unchanged: `192.168.72.2:/appdata/audio_cds` → `/mnt/audio_cds`.

On gluttony the files are `/mnt/4tb/a/md1/appdata/audio_cds`, bind-mounted at `/srv/nfs/appdata/audio_cds`. `/mnt/tnas/md1/appdata` is an empty stub on the root disk. A client mount that stays up across a server volume change returns "Stale file handle" while `findmnt` still says it is mounted. Fix is `umount -f /mnt/audio_cds` and let the automount bring it back. `/mnt/movies` and `/mnt/shows` are the same export family.

## Deploy

From a desk checkout, after the commit is on gluttony:

```bash
ssh haruna
cd ~/Ruby-on-Rails-Wizardry/mixomancer
git fetch gluttony && git reset --hard gluttony/main
sudo rsync -a \
  --exclude .git --exclude log --exclude tmp --exclude storage \
  --exclude vendor --exclude public/assets --exclude config/master.key --exclude .bundle \
  ~/Ruby-on-Rails-Wizardry/mixomancer/ /opt/mixomancer/
sudo chown -R haruna:haruna /opt/mixomancer
sudo systemctl restart mixomancer
```

Do not rsync `--delete` onto `/opt/mixomancer`. That tree holds `vendor/`, `storage/`, `master.key`, and compiled assets that are not in git. `chown -R` is safe; the key stays mode 600 if you do not replace the file.

Gems and assets, only when `Gemfile.lock` or asset inputs changed:

```bash
sudo -u haruna -H bash -lc 'cd /opt/mixomancer && mise exec -- bundle install && RAILS_ENV=production mise exec -- bin/rails assets:precompile'
```

## Traps

- **`rails server` binds `0.0.0.0:3000` unless told otherwise.** The unit passes `-b 127.0.0.1 -p 3000`. `config/puma.rb`'s `BIND` default is not enough, because the Rails server command overrides it. Thruster is the only public listener.
- **Do not set `NoNewPrivileges=` or `CapabilityBoundingSet=`** on `mixomancer.service`. Either one stops `sudo` from working, and the site then reports "Nothing playing" even while mpv is running. `AmbientCapabilities=CAP_NET_BIND_SERVICE` is what lets Thruster bind port 80 as `haruna`.
- **Do not use `%U` or `%h` in these system units.** For the system manager those expand to root (uid 0, `/root`), not `User=haruna`. The runtime dir is hardcoded `/run/user/2003`. The kiosk profile is hardcoded `/home/haruna/.config/mixomancer-kiosk`.
- **`bin/play-audio` uses `set -o pipefail`.** A failing `pactl` in the sink wait loop must end with `|| true`, or the unit exits in the same second instead of waiting for PipeWire.
- **One PipeWire owner.** Starting `rob`'s PipeWire again makes haruna's analog sink disappear.
- **Kiosk health check is `http://127.0.0.1/up`.** That is Thruster, not port 3000.
- **QR / control URL** is `http://haruna.lan` (`MIXOMANCER_URL`). Production `config.hosts` allows `haruna.lan`, `mixomancer.lan`, `haruna.local`, `mixomancer.local`, `haruna`, `192.168.72.3`, `localhost`, and `127.0.0.1`. Do not turn on `force_ssl`.
