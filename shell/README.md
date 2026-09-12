# Widget shell OmaCloud

Plugin de barra Omarchy (`bar-widget`): lee
`~/.local/state/omacloud/status.json` (contrato ADR-002) y muestra el
estado del sync. Nunca habla con Google.

- Click nube: fuerza `omacloud-bisync` (async, el estado se refresca solo).
- Click carpeta: abre `~/Drive`.
- Tooltip: estado + último sync + error si lo hay. Refresco cada 60 s.

## Instalación (dev: symlink al repo como fuente de verdad)

```bash
omarchy plugin validate ./shell/omacloud
mkdir -p ~/.config/omarchy/plugins
ln -sfn "$PWD/shell/omacloud" ~/.config/omarchy/plugins/omacloud
omarchy-shell shell rescanPlugins
omarchy plugin enable omacloud
```
