# Backend OmaCloud

Dos vías de acceso a Drive:

| Vía | Ruta | Mecanismo |
|-----|------|-----------|
| Vista en vivo | `~/Drive` | `rclone mount` (`omacloud-mount.service`) |
| Réplica local | `~/.local/share/omacloud/replica` | `rclone bisync` cada 15 min (`omacloud-bisync.timer`) |

## Estado (contrato con el widget, ADR-002)

`~/.local/state/omacloud/status.json`:

```json
{"status":"ok|syncing|error","last_sync":"...","last_error":"...","updated":"..."}
```

Lo escribe `omacloud-bisync` en cada corrida. El widget (Hito 3) lo lee;
no habla con Google.

## Instalación

```bash
cp backend/omacloud-bisync ~/.local/bin/ && chmod +x ~/.local/bin/omacloud-bisync
cp backend/*.service backend/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
# Primera vez: puebla la réplica (requiere --resync una sola vez)
rclone mkdir OmaCloud: 2>/dev/null  # idempotente, el root ya existe
rclone bisync ~/.local/share/omacloud/replica OmaCloud: --resync
systemctl --user enable --now omacloud-mount.service omacloud-bisync.timer
```

## Notas

- `bisync` **aborta** (no borra) si un lado queda vacío o si detecta
  cambios que requieren `--resync`; en ese caso `status.json` queda en
  `error` con el motivo y hay que intervenir manualmente.
- OAuth client_id propio configurado y verificado (2026-09-12); el
  compartido de rclone ya no se usa.
- Secretos (`~/.config/omacloud/.env`, permisos 600, **fuera del repo**):
  `OMACLOUD_CLIENT_ID` / `OMACLOUD_CLIENT_SECRET` más overrides
  opcionales (`OMACLOUD_REMOTE`, `OMACLOUD_REPLICA`). El wrapper los
  carga si el archivo existe.

## Sync selectivo (pares)

Por defecto se sincroniza el Drive completo. Con pares en
`~/.config/omacloud/pairs` (una línea `REMOTE | LOCAL` por par) solo se
sincronizan esas carpetas:

```bash
omacloud-config add-pair "OmaCloud:Proyectos" "~/Drive-sel/Proyectos"
omacloud-config list-pairs
omacloud-config remove-pair "~/Drive-sel/Proyectos"
```

- Archivo ausente o vacío = Drive completo (compatible hacia atrás).
- Cada par nuevo corre `--resync` una sola vez (marcador en el state dir).
- El estado publicado es el agregado (peor caso gana).
- Carpetas de "Computadoras" (ej. respaldos de otra máquina): no aparecen
  en el listado; usa el ID de su URL (`drive.google.com/drive/folders/<ID>`):
  `OmaCloud,root_folder_id=<ID>: | ~/destino`.
- El mount de `~/Drive` siempre muestra todo; lo selectivo aplica a la réplica.

## Notificaciones

El wrapper avisa solo en cambios de estado (sin spam): error nuevo
(crítica) y recuperación (normal). Los fallos repetidos no re-notifican.

## Recuperación (nunca auto-resync)

Si `status.json` queda en `error`:

1. Lee el motivo: `cat ~/.local/state/omacloud/status.json` y la cola de
   `~/.local/state/omacloud/bisync.log`.
2. Errores de red / rate-limit: no hagas nada, el timer reintenta solo.
3. `Must run --resync` o `empty listing`: un lado cambió de forma que
   bisync no reconcilia solo. Revisa qué se borró/movió en Drive y en la
   réplica **antes** de forzar nada.
4. Solo cuando entiendas el diff: `rclone bisync <replica> OmaCloud: --resync --verbose --dry-run` primero, y sin `--dry-run` después.
5. Verifica `status.json` en `ok` en la siguiente corrida.
