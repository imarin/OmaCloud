#!/usr/bin/env bash
# OmaCloud: instalación y configuración (idempotente, ES/EN según locale).
# Automatiza INSTALL.md. El auth OAuth abre el navegador una vez.
set -u

REPO="$(cd "$(dirname "$0")" && pwd)"
REMOTE="${OMACLOUD_REMOTE:-OmaCloud:}"
REPLICA="${OMACLOUD_REPLICA:-$HOME/.local/share/omacloud/replica}"
ENV_FILE="$HOME/.config/omacloud/.env"

# Idioma: español si el locale empieza por "es", inglés en otro caso.
if [[ "${LC_ALL:-${LANG:-en}}" =~ ^es ]]; then
  M_TITLE="== OmaCloud: instalación =="
  M_NO_RCLONE="falta rclone: corre 'omarchy pkg add rclone' y reintenta"
  M_RCLONE="rclone"
  M_NO_ENV="falta %s (ver INSTALL.md paso 3)"
  M_NO_KEYS="%s sin OMACLOUD_CLIENT_ID/SECRET (ver INSTALL.md paso 3)"
  M_SECRETS="secretos en %s"
  M_REMOTE_EXISTS="remote OmaCloud existe"
  M_REMOTE_NEW="creando remote OmaCloud (autoriza en el navegador)…"
  M_REMOTE_FAIL="no se pudo crear el remote"
  M_NO_ACCESS="sin acceso a Drive (revisa test user y Drive API en INSTALL.md paso 2)"
  M_ACCESS="acceso a Drive verificado"
  M_BACKEND="script + units instalados"
  M_SEED_ASK="la réplica está vacía; poblarla descarga tu Drive (~puede tardar)"
  M_SEED_PROMPT="¿Poblar ahora con --resync? [s/N] "
  M_SEED_SKIP="omitido: corre 'rclone bisync %s %s --resync' cuando quieras"
  M_SEED_DONE="réplica ya poblada"
  M_SEED_FAIL="falló el resync inicial"
  M_MOUNT_OK="mount activo en ~/Drive"
  M_MOUNT_FAIL="el mount no arrancó (ver logs: journalctl --user -u omacloud-mount)"
  M_PLUGIN_OK="plugin válido"
  M_PLUGIN_FAIL="plugin inválido"
  M_WIDGET_OK="widget habilitado a la derecha"
  M_WIDGET_FAIL="no se pudo habilitar el widget"
  M_MENU_OK="menú OmaCloud instalado"
  M_MENU_FAIL="no se pudo actualizar el menú"
  M_DONE="== Listo =="
  M_BAR="Verifica la barra: ☁️ estado/sync, 📁 abrir Drive."
else
  M_TITLE="== OmaCloud: setup =="
  M_NO_RCLONE="rclone missing: run 'omarchy pkg add rclone' and retry"
  M_RCLONE="rclone"
  M_NO_ENV="missing %s (see INSTALL.md step 3)"
  M_NO_KEYS="%s has no OMACLOUD_CLIENT_ID/SECRET (see INSTALL.md step 3)"
  M_SECRETS="secrets in %s"
  M_REMOTE_EXISTS="OmaCloud remote exists"
  M_REMOTE_NEW="creating OmaCloud remote (authorize in the browser)…"
  M_REMOTE_FAIL="could not create the remote"
  M_NO_ACCESS="no Drive access (check test user and Drive API in INSTALL.md step 2)"
  M_ACCESS="Drive access verified"
  M_BACKEND="script + units installed"
  M_SEED_ASK="replica is empty; seeding downloads your Drive (~may take a while)"
  M_SEED_PROMPT="Seed now with --resync? [y/N] "
  M_SEED_SKIP="skipped: run 'rclone bisync %s %s --resync' whenever you want"
  M_SEED_DONE="replica already seeded"
  M_SEED_FAIL="initial resync failed"
  M_MOUNT_OK="mount active at ~/Drive"
  M_MOUNT_FAIL="mount did not start (check logs: journalctl --user -u omacloud-mount)"
  M_PLUGIN_OK="plugin valid"
  M_PLUGIN_FAIL="plugin invalid"
  M_WIDGET_OK="widget enabled on the right"
  M_WIDGET_FAIL="could not enable the widget"
  M_MENU_OK="OmaCloud menu installed"
  M_MENU_FAIL="could not update the menu"
  M_DONE="== Done =="
  M_BAR="Check the bar: ☁️ status/sync, 📁 open Drive."
fi

ok() { echo "  ✅ $1"; }
info() { echo "  ➜ $1"; }
die() { echo "  ❌ $1" >&2; exit 1; }

echo "$M_TITLE"

# 1. rclone
command -v rclone >/dev/null || die "$M_NO_RCLONE"
ok "$M_RCLONE $(rclone version 2>/dev/null | head -n1 | awk '{print $2}')"

# 2. secretos
[ -f "$ENV_FILE" ] || die "$(printf "$M_NO_ENV" "$ENV_FILE")"
# shellcheck disable=SC1091
. "$ENV_FILE"
[ -n "${OMACLOUD_CLIENT_ID:-}" ] && [ -n "${OMACLOUD_CLIENT_SECRET:-}" ] \
  || die "$(printf "$M_NO_KEYS" "$ENV_FILE")"
ok "$(printf "$M_SECRETS" "$ENV_FILE")"

# 3. remote rclone (abre el navegador la primera vez)
if rclone listremotes 2>/dev/null | grep -qx "OmaCloud:"; then
  ok "$M_REMOTE_EXISTS"
else
  info "$M_REMOTE_NEW"
  rclone config create OmaCloud drive \
    client_id "$OMACLOUD_CLIENT_ID" client_secret "$OMACLOUD_CLIENT_SECRET" \
    || die "$M_REMOTE_FAIL"
fi
unset OMACLOUD_CLIENT_ID OMACLOUD_CLIENT_SECRET
rclone lsd "$REMOTE" >/dev/null 2>&1 || die "$M_NO_ACCESS"
ok "$M_ACCESS"

# 4. backend
install -m755 "$REPO/backend/omacloud-bisync" "$HOME/.local/bin/omacloud-bisync"
cp "$REPO/backend/"*.service "$REPO/backend/"*.timer "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
ok "$M_BACKEND"
if [ -z "$(ls -A "$REPLICA" 2>/dev/null)" ]; then
  info "$M_SEED_ASK"
  printf "%s" "$M_SEED_PROMPT"
  read -r -t 60 REPLY || REPLY=n
  if [[ "$REPLY" =~ ^[sSyY] ]]; then
    mkdir -p "$REPLICA"
    rclone bisync "$REPLICA" "$REMOTE" --resync || die "$M_SEED_FAIL"
  else
    # shellcheck disable=SC2059
    info "$(printf "$M_SEED_SKIP" "$REPLICA" "$REMOTE")"
  fi
else
  ok "$M_SEED_DONE"
fi
systemctl --user enable --quiet omacloud-mount.service omacloud-bisync.timer
systemctl --user start omacloud-mount.service omacloud-bisync.timer 2>/dev/null || true
systemctl --user is-active --quiet omacloud-mount.service \
  && ok "$M_MOUNT_OK" || die "$M_MOUNT_FAIL"

# 5. widget
omarchy plugin validate "$REPO/shell/omacloud" >/dev/null \
  && ok "$M_PLUGIN_OK" || die "$M_PLUGIN_FAIL"
mkdir -p "$HOME/.config/omarchy/plugins"
ln -sfn "$REPO/shell/omacloud" "$HOME/.config/omarchy/plugins/omacloud"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable omacloud --section right >/dev/null \
  && ok "$M_WIDGET_OK" || die "$M_WIDGET_FAIL"

# 6. menú omarchy (fusión por texto: conserva comentarios del usuario)
if python3 - "$REPO/extras/omacloud-menu.jsonc" "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc" <<'EOF' | grep -q "MENU_ADDED\|MENU_PRESENT"
import json, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    entries = [l.strip() for l in f if l.strip().startswith('"omacloud')]
with open(dst) as f:
    cur = f.read()
if '"omacloud.open"' in cur:
    print("MENU_PRESENT")
else:
    shutil.copy(dst, dst + ".bak.omacloud")
    block = "  // OmaCloud (install.sh — no editar a mano).\n" + "\n".join("  " + l for l in entries) + "\n"
    idx = cur.rstrip().rfind("}")
    cur = cur.rstrip()[:idx].rstrip() + "\n" + block + "}\n"
    stripped = "\n".join(l for l in cur.splitlines() if not l.strip().startswith("//"))
    json.loads(stripped)  # valida antes de escribir
    with open(dst, "w") as f:
        f.write(cur)
    print("MENU_ADDED")
EOF
then
  ok "$M_MENU_OK"
else
  die "$M_MENU_FAIL"
fi

echo "$M_DONE"
cat "$HOME/.local/state/omacloud/status.json" 2>/dev/null || true
echo "$M_BAR"
