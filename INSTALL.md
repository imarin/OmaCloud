# Install — OmaCloud v1

Google Drive client for Omarchy: `rclone` (mount + bisync) + bar widget.
Estimated time: 20–30 min (first sync depends on your Drive size).

[Guía en español](INSTALL.es.md).

## Requirements

- Omarchy (Arch Linux + Hyprland + Quickshell).
- Google account with Drive access.
- `git` installed.

## 0. Clone the repo

```bash
cd ~
git clone https://github.com/imarin/OmaCloud.git
```

This creates `~/OmaCloud` with the code (steps 5 and 6 enter it with
`cd ~/OmaCloud`).

Quick way (clone and run the installer):

```bash
git clone https://github.com/imarin/OmaCloud.git ~/OmaCloud && ~/OmaCloud/install.sh
```

The script is idempotent and bilingual (ES/EN per your locale); it detects
what is already installed and only configures the rest. OAuth auth opens
the browser once.

## 1. rclone

```bash
omarchy pkg add rclone   # or: sudo pacman -S rclone
rclone version
```

## 2. Your own OAuth credentials (Google Cloud Console)

rclone ships a shared `client_id` that is being retired; use your own:

1. Create a project at [Google Cloud Console](https://console.cloud.google.com/).
2. **APIs & Services → Library**: enable **Google Drive API**.
3. **APIs & Services → OAuth consent screen**: app in *Testing* mode, add
   yourself as a **test user** with your Gmail account.
4. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   (type *Desktop app*). Note the client_id and client_secret.
   - Without the test user you will see `Error 403: access_denied`.
   - If a denied attempt gets "stuck", revoke it at
     [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
     and retry.

## 3. Local secrets

```bash
mkdir -p ~/.config/omacloud
cat > ~/.config/omacloud/.env <<EOF
OMACLOUD_CLIENT_ID=your-client-id
OMACLOUD_CLIENT_SECRET=your-client-secret
EOF
chmod 600 ~/.config/omacloud/.env
```

This file lives **outside the repo** and is never committed.

## 4. rclone remote + authorization

```bash
set -a; . ~/.config/omacloud/.env; set +a
rclone config create OmaCloud drive \
  client_id "$OMACLOUD_CLIENT_ID" client_secret "$OMACLOUD_CLIENT_SECRET"
unset OMACLOUD_CLIENT_ID OMACLOUD_CLIENT_SECRET
```

Answer `y` (use browser), `n` (not a Shared Drive) and authorize in the
browser. Verify:

```bash
rclone lsd OmaCloud:
```

Note: if you ever rotate the keys or the token is invalidated, re-authorize
with `rclone config reconnect OmaCloud:` (answer `y`, `y`, `n`).

## 5. Backend (service)

Live view at `~/Drive` + local replica synced every 15 min:

```bash
cd ~/OmaCloud
cp backend/omacloud-bisync ~/.local/bin/ && chmod +x ~/.local/bin/omacloud-bisync
cp backend/*.service backend/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
mkdir -p ~/.local/share/omacloud/replica
rclone bisync ~/.local/share/omacloud/replica OmaCloud: --resync  # first time only
systemctl --user enable --now omacloud-mount.service omacloud-bisync.timer
ls ~/Drive   # your live Drive
cat ~/.local/state/omacloud/status.json   # {"status":"ok",...}
```

## 6. Bar widget

```bash
cd ~/OmaCloud
omarchy plugin validate ./shell/omacloud
mkdir -p ~/.config/omarchy/plugins
ln -sfn "$PWD/shell/omacloud" ~/.config/omarchy/plugins/omacloud
omarchy-shell shell rescanPlugins
omarchy plugin enable omacloud --section right
```

You will see ☁️ (status; click = force sync) and 📁 (open `~/Drive`). The
tooltip shows status, last sync and errors.

## 7. Verify

```bash
systemctl --user is-active omacloud-mount.service omacloud-bisync.timer
cat ~/.local/state/omacloud/status.json
omarchy plugin list | grep omacloud
```

## Notes

- `bisync` **aborts without deleting** if one side is empty or requires
  `--resync`; then `status.json` holds `error` with the reason: check it
  before forcing anything.
- Each run's log is at `~/.local/state/omacloud/bisync.log`.

## Uninstall

```bash
systemctl --user disable --now omacloud-mount.service omacloud-bisync.timer
omarchy plugin disable omacloud
rm -rf ~/.config/systemd/user/omacloud-* ~/.local/bin/omacloud-bisync \
  ~/.config/omarchy/plugins/omacloud ~/Drive ~/.local/share/omacloud
# Optional: revoke access at myaccount.google.com/permissions
# and delete ~/.config/omacloud/.env + ~/.config/rclone/rclone.conf
```
