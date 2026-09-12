# OmaCloud

Cliente de Google Drive para [Omarchy](https://omarchy.org/).

**Arquitectura decidida:** híbrida — backend de sincronización con `rclone`
(mount + bi-sync) + widget de barra Quickshell (QML) para estado y acciones.

**Estado:** fundación. Sin implementación todavía. El roadmap y las
decisiones viven en el board Kanban `omacloud`.

## Estructura prevista (no implementada aún)

- `backend/` — servicio rclone: mount, bi-sync, auth OAuth
- `shell/` — plugin Omarchy (`manifest.json` + QML): estado sync, acciones
- `docs/` — visión, decisiones (ADR), roadmap

## Instalación

Ver [INSTALL.md](INSTALL.md) — guía punta a punta (rclone, OAuth, servicio, widget).

## Requisitos previos

- Omarchy (Arch Linux + Hyprland + Quickshell)
- `rclone` (aún no instalado — ver roadmap)
- Cuenta de Google con acceso a Drive API / OAuth

## Estado

Proyecto en fase de fundación, sin implementación todavía.
