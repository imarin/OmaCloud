# OmaCloud

Cliente de Google Drive para [Omarchy](https://omarchy.org/). Combina
sincronización con `rclone` (mount + bi-sync) y un widget de barra
Quickshell (QML) para estado y acciones.

**Estado: v1 funcional.** Monta tu Drive en `~/Drive`, mantiene una
réplica local sincronizada cada 15 min como servicio de usuario, y muestra
el estado en la barra (click nube = forzar sync, click carpeta = abrir
Drive).

## Estructura

- `backend/` — wrapper `omacloud-bisync` + units systemd (mount, bisync, timer)
- `shell/omacloud/` — plugin Omarchy (`manifest.json` + QML)
- `docs/` — visión, decisiones (ADR), roadmap, nota del spike rclone
- `INSTALL.md` — guía de instalación punta a punta

## Instalación

Ver [INSTALL.md](INSTALL.md): rclone, OAuth con client_id propio,
servicio y widget.

## Requisitos

- Omarchy (Arch Linux + Hyprland + Quickshell)
- `rclone`
- Cuenta de Google con acceso a Drive (se usa un OAuth client_id propio;
  detalles en INSTALL.md)
