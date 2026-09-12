import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// OmaCloud: estado del sync contra status.json (contrato ADR-002).
// Nube: click izquierdo = forzar sync | click derecho = menú.
// Carpeta: abrir ~/Drive.
BarWidget {
  id: root
  moduleName: "omacloud"

  property string syncStatus: "unknown" // ok | syncing | error | unknown
  property string lastSync: "never"
  property string lastError: ""
  property bool menuOpen: false
  property string interval: "?"
  property string menuMsg: ""
  property string keysId: ""
  property string keysSecret: ""

  readonly property string home: Quickshell.env("HOME")
  readonly property string statusFile: home + "/.local/state/omacloud/status.json"
  readonly property string helper: home + "/.local/bin/omacloud-config"
  readonly property bool spanish: {
    var loc = Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "en";
    return loc.substring(0, 2) === "es";
  }
  readonly property var str: root.spanish ? {
    lastSync: "Último sync",
    openDrive: "Abrir Drive",
    syncTip: "Click: sincronizar | Click derecho: menú",
    menuTitle: "OmaCloud",
    forceSync: "Sincronizar ahora",
    open: "Abrir Drive",
    frequency: "Frecuencia de sync (min)",
    apiKeys: "Claves API de Google",
    idPh: "Client ID",
    secretPh: "Client secret",
    save: "Guardar claves",
    reconnect: "Re-autorizar en navegador",
    savedOk: "Claves guardadas y acceso verificado.",
    needsAuth: "Claves guardadas. Pulsa Re-autorizar y acepta en el navegador.",
    reconnectOk: "Autorización completa.",
    reconnectFail: "Falló. Revisa el navegador e inténtalo de nuevo.",
    freqOk: "Frecuencia actualizada.",
    freqFail: "No se pudo cambiar (1–120)."
  } : {
    lastSync: "Last sync",
    openDrive: "Open Drive",
    syncTip: "Click: sync now | Right-click: menu",
    menuTitle: "OmaCloud",
    forceSync: "Sync now",
    open: "Open Drive",
    frequency: "Sync frequency (min)",
    apiKeys: "Google API keys",
    idPh: "Client ID",
    secretPh: "Client secret",
    save: "Save keys",
    reconnect: "Re-authorize in browser",
    savedOk: "Keys saved and access verified.",
    needsAuth: "Keys saved. Press Re-authorize and accept in the browser.",
    reconnectOk: "Authorization complete.",
    reconnectFail: "Failed. Check the browser and try again.",
    freqOk: "Frequency updated.",
    freqFail: "Could not change (1–120)."
  }

  function refresh() {
    if (!readProc.running) {
      readProc.command = ["cat", statusFile]
      readProc.running = true
    }
  }

  function forceSync() {
    if (!syncProc.running) {
      root.syncStatus = "syncing"
      syncProc.running = true
    }
  }

  function openFolder() {
    if (!openProc.running) {
      openProc.command = ["xdg-open", home + "/Drive"]
      openProc.running = true
    }
  }

  function toggleMenu() {
    root.menuMsg = ""
    if (!root.menuOpen) {
      cfgProc.mode = "get-interval"
      cfgProc.command = [root.helper, "get-interval"]
      cfgProc.running = true
    }
    root.menuOpen = !root.menuOpen
  }

  function setInterval(mins) {
    cfgProc.mode = "set-interval"
    cfgProc.command = [root.helper, "set-interval", String(mins)]
    cfgProc.running = true
  }

  function saveKeys() {
    if (root.keysId === "" || root.keysSecret === "") return
    // Las claves viajan por stdin, nunca por argv.
    keysProc.secret = root.keysId + "\n" + root.keysSecret + "\n"
    keysProc.running = true
  }

  function reconnect() {
    cfgProc.mode = "reconnect"
    cfgProc.command = ["sh", "-c", "printf 'y\\ny\\nn\\n' | rclone config reconnect OmaCloud: 2>&1 | tail -n 4"]
    cfgProc.running = true
  }

  function statusIcon() {
    if (root.syncStatus === "syncing") return "\uf021"
    if (root.syncStatus === "error") return "\uf071"
    return "\uf0c2"
  }

  function statusWord() {
    if (root.syncStatus === "syncing") return root.spanish ? "sincronizando" : "syncing";
    if (root.syncStatus === "error") return "error";
    if (root.syncStatus === "ok") return "ok";
    return root.spanish ? "desconocido" : "unknown";
  }

  function statusTip() {
    var tip = "OmaCloud: " + root.statusWord() + "\n" + root.str.lastSync + ": " + root.lastSync + "\n" + root.str.syncTip
    if (root.syncStatus === "error" && root.lastError !== "") tip += "\n" + root.lastError
    return tip
  }

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Process {
    id: readProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.syncStatus = data.status || "unknown"
          root.lastSync = data.last_sync || "never"
          root.lastError = data.last_error || ""
        } catch (e) {
          root.syncStatus = "unknown"
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.syncStatus = "unknown"
    }
  }

  Process {
    id: syncProc
    command: [home + "/.local/bin/omacloud-bisync"]
    onExited: root.refresh()
  }

  Process {
    id: openProc
  }

  Process {
    id: cfgProc
    property string mode: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = text.trim()
        if (cfgProc.mode === "get-interval" || cfgProc.mode === "set-interval") {
          if (/^[0-9]+$/.test(out)) {
            root.interval = out
            if (cfgProc.mode === "set-interval") root.menuMsg = root.str.freqOk
          } else {
            root.menuMsg = root.str.freqFail
          }
        } else if (cfgProc.mode === "reconnect") {
          root.menuMsg = /Got code/.test(out) ? root.str.reconnectOk : root.str.reconnectFail + "\n" + out
          root.refresh()
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && cfgProc.mode !== "reconnect") root.menuMsg = root.str.freqFail
    }
  }

  Process {
    id: keysProc
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      write(secret)
      secret = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = text.trim()
        root.keysId = ""
        root.keysSecret = ""
        if (out === "SAVED_OK") root.menuMsg = root.str.savedOk
        else if (out === "SAVED_NEEDS_AUTH") root.menuMsg = root.str.needsAuth
        else root.menuMsg = out
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Row {
    id: row
    BarIconButton {
      id: cloudBtn
      bar: root.bar
      text: root.statusIcon()
      slotSize: Style.bar.statusSlot
      fontSize: Style.font.caption
      tooltipText: root.statusTip()
      active: root.syncStatus === "error"
      onPressed: function(button) {
        if (button === Qt.RightButton) root.toggleMenu()
        else root.forceSync()
      }
    }
    BarIconButton {
      bar: root.bar
      text: "\uf07b"
      slotSize: Style.bar.statusSlot
      fontSize: Style.font.caption
      tooltipText: root.str.openDrive
      onPressed: root.openFolder()
    }
  }

  PopupCard {
    id: menuPopup
    anchorItem: cloudBtn
    owner: root
    bar: root.bar
    open: root.menuOpen
    contentWidth: Style.space(300)
    contentHeight: menuPopup.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        text: root.str.menuTitle + " — " + root.statusWord()
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Button {
        text: root.str.forceSync
        onClicked: {
          root.menuOpen = false
          root.forceSync()
        }
      }

      Button {
        text: root.str.open
        onClicked: {
          root.menuOpen = false
          root.openFolder()
        }
      }

      Text {
        text: root.str.frequency + " (" + root.interval + ")"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Row {
        spacing: Style.space(6)
        Repeater {
          model: [2, 5, 15, 30]
          Button {
            required property int modelData
            text: String(modelData)
            onClicked: root.setInterval(modelData)
          }
        }
      }

      Text {
        text: root.str.apiKeys
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      TextField {
        width: parent.width
        placeholderText: root.str.idPh
        text: root.keysId
        onTextChanged: root.keysId = text
        font.family: Style.font.family
      }

      TextField {
        width: parent.width
        placeholderText: root.str.secretPh
        echoMode: TextInput.Password
        text: root.keysSecret
        onTextChanged: root.keysSecret = text
        font.family: Style.font.family
      }

      Button {
        text: root.str.save
        onClicked: root.saveKeys()
      }

      Button {
        text: root.str.reconnect
        onClicked: root.reconnect()
      }

      Text {
        visible: root.menuMsg !== ""
        text: root.menuMsg
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }
    }
  }
}
