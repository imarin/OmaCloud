import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
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
  property int freqPreview: -1
  property var pairs: []
  property string newRemote: ""
  property string newLocal: ""
  property bool browsing: false
  property string browsePath: ""
  property var browseList: []
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
    frequency: "Frecuencia de sync, min (0 = manual)",
    manual: "manual",
    apiKeys: "Claves API de Google",
    idPh: "Client ID",
    secretPh: "Client secret",
    save: "Guardar claves",
    reconnect: "Re-autorizar en navegador",
    quit: "Cerrar OmaCloud",
    pairs: "Carpetas sincronizadas",
    fullDrive: "Drive completo",
    remotePh: "Drive:Carpeta (o ID de Computadoras)",
    localPh: "Destino, ej. ~/MisDocs",
    add: "Agregar par",
    srcLbl: "Origen",
    dstLbl: "Destino",
    browse: "Examinar Drive",
    chooseDest: "Elegir destino",
    useHere: "Usar esta carpeta",
    goUp: "Subir",
    savedOk: "Claves guardadas y acceso verificado.",
    needsAuth: "Claves guardadas. Pulsa Re-autorizar y acepta en el navegador.",
    reconnectOk: "Autorización completa.",
    reconnectFail: "Falló. Revisa el navegador e inténtalo de nuevo.",
    freqOk: "Frecuencia actualizada.",
    freqFail: "No se pudo cambiar (0–120)."
  } : {
    lastSync: "Last sync",
    openDrive: "Open Drive",
    syncTip: "Click: sync now | Right-click: menu",
    menuTitle: "OmaCloud",
    forceSync: "Sync now",
    open: "Open Drive",
    frequency: "Sync frequency, min (0 = manual)",
    manual: "manual",
    apiKeys: "Google API keys",
    idPh: "Client ID",
    secretPh: "Client secret",
    save: "Save keys",
    reconnect: "Re-authorize in browser",
    quit: "Quit OmaCloud",
    pairs: "Synced folders",
    fullDrive: "Full Drive",
    remotePh: "Drive:Folder (or Computers ID)",
    localPh: "Destination, e.g. ~/MyDocs",
    add: "Add pair",
    srcLbl: "Source",
    dstLbl: "Destination",
    browse: "Browse Drive",
    chooseDest: "Choose destination",
    useHere: "Use this folder",
    goUp: "Up",
    savedOk: "Keys saved and access verified.",
    needsAuth: "Keys saved. Press Re-authorize and accept in the browser.",
    reconnectOk: "Authorization complete.",
    reconnectFail: "Failed. Check the browser and try again.",
    freqOk: "Frequency updated.",
    freqFail: "Could not change (0–120)."
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
      loadPairs()
    }
    root.menuOpen = !root.menuOpen
  }

  function loadPairs() {
    if (!pairsProc.running) {
      pairsProc.command = ["cat", home + "/.config/omacloud/pairs"]
      pairsProc.running = true
    }
  }

  function addPair() {
    if (root.newRemote === "" || root.newLocal === "" || cfgProc.running) return
    cfgProc.mode = "pair-change"
    cfgProc.command = [root.helper, "add-pair", root.newRemote, root.newLocal]
    cfgProc.running = true
  }

  function removePair(local) {
    if (cfgProc.running) return
    cfgProc.mode = "pair-change"
    cfgProc.command = [root.helper, "remove-pair", local]
    cfgProc.running = true
  }

  function toggleBrowse() {
    if (root.browsing) {
      root.browsing = false
      return
    }
    root.browsing = true
    browseLoad()
  }

  function browseLoad() {
    if (browseProc.running) return
    browseProc.command = [root.helper, "list-dirs", root.browsePath]
    browseProc.running = true
  }

  function browseDown(name) {
    root.browsePath = root.browsePath === "" ? name : root.browsePath + "/" + name
    browseLoad()
  }

  function browseUp() {
    var i = root.browsePath.lastIndexOf("/")
    root.browsePath = i === -1 ? "" : root.browsePath.substring(0, i)
    browseLoad()
  }

  function useFolder() {
    root.newRemote = "OmaCloud:" + root.browsePath
    root.browsing = false
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

  // Sin binding open<->menuOpen: el popup rompe bindings al cerrarse solo
  // (foco fuera); se sincroniza manual en ambas direcciones.
  onMenuOpenChanged: menuPopup.open = root.menuOpen
  // Sincronización manual igual que el menú (el cierre externo rompe bindings).
  onBrowsingChanged: browsePopup.open = root.browsing

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
        } else if (cfgProc.mode === "pair-change") {
          if (out === "ADDED" || out === "REMOVED") {
            root.newRemote = ""
            root.newLocal = ""
            root.menuMsg = ""
            root.loadPairs()
          } else {
            root.menuMsg = out
          }
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

  Process {
    id: pairsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          if (line === "" || line.charAt(0) === "#") continue
          var sep = line.indexOf("|")
          if (sep === -1) continue
          list.push({
            remote: line.substring(0, sep).trim(),
            local: line.substring(sep + 1).trim()
          })
        }
        root.pairs = list
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.pairs = []
    }
  }

  Process {
    id: browseProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          if (line !== "") list.push(line)
        }
        root.browseList = list
      }
    }
  }

  Process {
    id: quitProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.trim() === "QUIT_OK" && root.bar) {
          root.bar.run("omarchy plugin disable omacloud")
        }
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

  FolderDialog {
    id: destDlg
    title: root.str.chooseDest
    currentFolder: root.home !== "" ? "file://" + root.home : ""
    onAccepted: {
      var u = String(destDlg.selectedFolder)
      if (u.substring(0, 7) === "file://") u = u.substring(7)
      root.newLocal = u
    }
  }

  Row {
    id: row
    focus: true
    Keys.onEscapePressed: root.menuOpen = false
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

  KeyboardPanel {
    id: menuPopup
    anchorItem: cloudBtn
    owner: root
    bar: root.bar
    focusTarget: menuColumn
    contentWidth: Style.space(300)
    contentHeight: menuPopup.fittedContentHeight(menuColumn.implicitHeight)
    onOpenChanged: {
      if (!open) root.menuOpen = false
      else Qt.callLater(function() {
        menuColumn.forceActiveFocus()
      })
    }

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: Style.space(8)
      focus: true
      Keys.onEscapePressed: root.menuOpen = false

      Text {
        text: root.str.menuTitle + " — " + root.statusWord()
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Row {
        width: parent.width
        spacing: Style.space(6)
        Button {
          width: (parent.width - Style.space(6)) / 2
          text: root.str.forceSync
          onClicked: {
            root.menuOpen = false
            root.forceSync()
          }
        }
        Button {
          width: (parent.width - Style.space(6)) / 2
          text: root.str.open
          onClicked: {
            root.menuOpen = false
            root.openFolder()
          }
        }
      }

      Text {
        text: {
          var v = root.freqPreview >= 0 ? root.freqPreview : root.interval
          return root.str.frequency + ": " + (String(v) === "0" ? root.str.manual : v)
        }
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Slider {
        width: parent.width
        from: 0
        to: 30
        stepSize: 1
        value: root.freqPreview >= 0 ? root.freqPreview : (parseInt(root.interval) || 0)
        onMoved: root.freqPreview = Math.round(value)
        onPressedChanged: {
          if (!pressed && root.freqPreview >= 0) {
            var v = root.freqPreview
            root.freqPreview = -1
            root.setInterval(v)
          }
        }
      }

      Text {
        text: root.str.pairs + (root.pairs.length === 0 ? " (" + root.str.fullDrive + ")" : "")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Repeater {
        model: root.pairs
        delegate: Row {
          required property var modelData
          width: menuColumn.width
          spacing: Style.space(6)
          Text {
            width: parent.width - pairDelBtn.width - Style.space(6)
            text: modelData.remote + " → " + modelData.local
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
          }
          Button {
            id: pairDelBtn
            text: "\uf00d"
            onClicked: root.removePair(modelData.local)
          }
        }
      }

      Text {
        text: root.str.srcLbl + ": " + (root.newRemote === "" ? "—" : root.newRemote)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
        width: parent.width
      }

      Button {
        id: browseBtn
        width: parent.width
        text: root.str.browse
        onClicked: root.toggleBrowse()
      }

      Text {
        text: root.str.dstLbl + ": " + (root.newLocal === "" ? "—" : root.newLocal)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
        width: parent.width
      }

      Button {
        width: parent.width
        text: root.str.chooseDest
        onClicked: destDlg.open()
      }

      Button {
        width: parent.width
        text: root.str.add
        onClicked: root.addPair()
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

      Button {
        width: parent.width
        text: root.str.quit
        onClicked: {
          root.menuOpen = false
          quitProc.command = [root.helper, "quit"]
          quitProc.running = true
        }
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

  KeyboardPanel {
    id: browsePopup
    anchorItem: browseBtn
    owner: root
    bar: root.bar
    focusTarget: browseColumn
    contentWidth: Style.space(300)
    contentHeight: browsePopup.fittedContentHeight(browseColumn.implicitHeight)
    onOpenChanged: {
      if (!open) root.browsing = false
    }

    Column {
      id: browseColumn
      anchors.fill: parent
      spacing: Style.space(8)
      focus: true
      Keys.onEscapePressed: root.browsing = false

      Text {
        text: "Drive:/" + root.browsePath
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideMiddle
        width: parent.width
      }

      Row {
        width: parent.width
        spacing: Style.space(6)
        Button {
          width: (parent.width - Style.space(6)) / 2
          text: root.str.goUp
          onClicked: root.browseUp()
        }
        Button {
          width: (parent.width - Style.space(6)) / 2
          text: root.str.useHere
          onClicked: root.useFolder()
        }
      }

      Repeater {
        model: root.browseList
        delegate: Button {
          required property string modelData
          width: browseColumn.width
          text: "\uf07b " + modelData
          onClicked: root.browseDown(modelData)
        }
      }
    }
  }
}
