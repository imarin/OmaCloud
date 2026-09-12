import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// OmaCloud: estado del sync contra status.json (contrato ADR-002).
// Click nube = forzar sync | click carpeta = abrir ~/Drive.
BarWidget {
  id: root
  moduleName: "omacloud"

  property string syncStatus: "unknown" // ok | syncing | error | unknown
  property string lastSync: "never"
  property string lastError: ""

  readonly property string home: Quickshell.env("HOME")
  readonly property string statusFile: home + "/.local/state/omacloud/status.json"
  readonly property bool spanish: {
    var loc = Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "en";
    return loc.substring(0, 2) === "es";
  }
  readonly property var str: root.spanish ? {lastSync: "Último sync", openDrive: "Abrir Drive"} : {lastSync: "Last sync", openDrive: "Open Drive"}

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

  function statusIcon() {
    if (root.syncStatus === "syncing") return "\uf021"
    if (root.syncStatus === "error") return "\uf071"
    return "\uf0c2"
  }

  function statusTip() {
    var tip = "OmaCloud: " + root.syncStatus + "\n" + root.str.lastSync + ": " + root.lastSync
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
      bar: root.bar
      text: root.statusIcon()
      slotSize: Style.bar.statusSlot
      fontSize: Style.font.caption
      tooltipText: root.statusTip()
      active: root.syncStatus === "error"
      onPressed: root.forceSync()
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
}
