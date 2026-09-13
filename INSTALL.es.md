# Instalación — OmaCloud v0.1.1

Cliente de Google Drive para Omarchy: `rclone` (mount + bisync) + widget
de barra. Tiempo estimado: 20–30 min (la primera sincronización depende
del tamaño de tu Drive).

[English guide](INSTALL.md).

## Requisitos

- Omarchy (Arch Linux + Hyprland + Quickshell).
- Cuenta de Google con acceso a Drive.
- `git` instalado.

## 0. Clonar el repo

```bash
cd ~
git clone https://github.com/imarin/OmaCloud.git
```

Esto crea `~/OmaCloud` con el código (los pasos 5 y 6 entran ahí con
`cd ~/OmaCloud`).

Vía rápida (clona y ejecuta el instalador):

```bash
git clone https://github.com/imarin/OmaCloud.git ~/OmaCloud && ~/OmaCloud/install.sh
```

El script es idempotente y bilingüe (ES/EN según tu locale); detecta lo
ya instalado y solo configura lo faltante. El auth OAuth abre el
navegador una vez.

## 1. rclone

```bash
omarchy pkg add rclone   # o: sudo pacman -S rclone
rclone version
```

## 2. Credenciales OAuth propias (Google Cloud Console)

rclone trae un `client_id` compartido en retirada; usa uno propio:

1. Crea un proyecto en [Google Cloud Console](https://console.cloud.google.com/).
2. **APIs y servicios → Biblioteca**: habilita **Google Drive API**.
3. **APIs y servicios → Pantalla de consentimiento OAuth**: app en modo
   *Prueba*, agrégate como **test user** con tu cuenta de Gmail.
4. **APIs y servicios → Credenciales → Crear credenciales → ID de cliente
   OAuth** (tipo *App de escritorio*). Anota client_id y client_secret.
   - Sin el test user verás `Error 403: access_denied`.
   - Si un intento denegado se queda "pegado", revócalo en
     [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
     y reintenta.

## 3. Secretos locales

```bash
mkdir -p ~/.config/omacloud
cat > ~/.config/omacloud/.env <<EOF
OMACLOUD_CLIENT_ID=tu-client-id
OMACLOUD_CLIENT_SECRET=tu-client-secret
EOF
chmod 600 ~/.config/omacloud/.env
```

Este archivo vive **fuera del repo** y nunca se commitea.

## 4. Remote rclone + autorización

```bash
set -a; . ~/.config/omacloud/.env; set +a
rclone config create OmaCloud drive \
  client_id "$OMACLOUD_CLIENT_ID" client_secret "$OMACLOUD_CLIENT_SECRET"
unset OMACLOUD_CLIENT_ID OMACLOUD_CLIENT_SECRET
```

Responde `y` (usar navegador), `n` (no es Shared Drive) y autoriza en el
navegador. Verifica:

```bash
rclone lsd OmaCloud:
```

Nota: si alguna vez cambias las claves o el token se invalida, re-autoriza
con `rclone config reconnect OmaCloud:` (responde `y`, `y`, `n`).

## 5. Backend (servicio)

Vista en vivo en `~/Drive` + réplica local sincronizada cada 15 min:

```bash
cd ~/OmaCloud
cp backend/omacloud-bisync ~/.local/bin/ && chmod +x ~/.local/bin/omacloud-bisync
cp backend/*.service backend/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
mkdir -p ~/.local/share/omacloud/replica
rclone bisync ~/.local/share/omacloud/replica OmaCloud: --resync  # solo la primera vez
systemctl --user enable --now omacloud-mount.service omacloud-bisync.timer
ls ~/Drive   # tu Drive en vivo
cat ~/.local/state/omacloud/status.json   # {"status":"ok",...}
```

## 6. Widget de barra

```bash
cd ~/OmaCloud
omarchy plugin validate ./shell/omacloud
mkdir -p ~/.config/omarchy/plugins
ln -sfn "$PWD/shell/omacloud" ~/.config/omarchy/plugins/omacloud
omarchy-shell shell rescanPlugins
omarchy plugin enable omacloud --section right
```

Verás ☁️ (estado; click = forzar sync) y 📁 (abrir `~/Drive`). El tooltip
muestra estado, último sync y errores.

El instalador agrega además el submenú OmaCloud al menú de Omarchy (abrir,
sincronizar, reactivar servicios + widget). Instalación manual: fusiona
`extras/omacloud-menu.jsonc` dentro de
`~/.config/omarchy/extensions/omarchy-menu.jsonc`.

## 7. Verificación

```bash
systemctl --user is-active omacloud-mount.service omacloud-bisync.timer
cat ~/.local/state/omacloud/status.json
omarchy plugin list | grep omacloud
```

## Notas

- `bisync` **aborta sin borrar** si un lado queda vacío o si requiere
  `--resync`; en ese caso `status.json` queda en `error` con el motivo:
  revísalo antes de forzar nada.
- El log de cada corrida está en `~/.local/state/omacloud/bisync.log`.

## Desinstalar

```bash
systemctl --user disable --now omacloud-mount.service omacloud-bisync.timer
omarchy plugin disable omacloud
rm -rf ~/.config/systemd/user/omacloud-* ~/.local/bin/omacloud-bisync \
  ~/.config/omarchy/plugins/omacloud ~/Drive ~/.local/share/omacloud
# Opcional: revocar el acceso en myaccount.google.com/permissions
# y borrar ~/.config/omacloud/.env + ~/.config/rclone/rclone.conf
```
