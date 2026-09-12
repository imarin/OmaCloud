# Backend OmaCloud

Dos vías de acceso a Drive (ver `docs/spike-rclone.md`):

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
- Sin `client_id` propio (ver tarjeta bloqueada en kanban) se usa el
  compartido de rclone hasta que Google lo retire en 2026.
- Secretos (`~/.config/omacloud/.env`, permisos 600, **fuera del repo**):
  `OMACLOUD_CLIENT_ID` / `OMACLOUD_CLIENT_SECRET` más overrides
  opcionales (`OMACLOUD_REMOTE`, `OMACLOUD_REPLICA`). El wrapper los
  carga si el archivo existe.
